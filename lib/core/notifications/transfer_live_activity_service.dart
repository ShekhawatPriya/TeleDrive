import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final transferLiveActivityServiceProvider =
    Provider<TransferLiveActivityService>(
      (ref) => TransferLiveActivityService.instance,
    );

/// Phases the iOS widget extension renders; names match the Swift enum.
/// `paused` is native-only: iOS suspending TeleDrive is not visible here.
enum TransferActivityPhase {
  preparing,
  uploading,
  waitingForWifi,
  completed,
  partial,
  failed,
  cancelled;

  bool get isTerminal =>
      this == completed ||
      this == partial ||
      this == failed ||
      this == cancelled;
}

enum TransferActivitySource { uploads, backup }

/// File categories the Live Activity has glyphs for.
enum TransferActivityFileKind { image, video, audio, document, archive, other }

/// What the upload Live Activity says at one moment. Built from real queue
/// state; counts cover this session only, never the whole library.
@immutable
class TransferActivitySnapshot {
  const TransferActivitySnapshot({
    required this.phase,
    required this.source,
    required this.totalCount,
    required this.completedCount,
    required this.failedCount,
    required this.progress,
    required this.completedBytes,
    required this.totalBytes,
    this.currentName,
    this.currentKind = TransferActivityFileKind.other,
  });

  final TransferActivityPhase phase;
  final TransferActivitySource source;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final double progress;
  final int completedBytes;
  final int totalBytes;
  final String? currentName;
  final TransferActivityFileKind currentKind;

  bool get isTerminal => phase.isTerminal;
  int get percent => (progress.clamp(0.0, 1.0) * 100).floor();

  Map<String, Object?> toMap() => {
    'phase': phase.name,
    'source': source.name,
    'totalCount': totalCount,
    'completedCount': completedCount,
    'failedCount': failedCount,
    'progress': progress.clamp(0.0, 1.0),
    'completedBytes': completedBytes,
    'totalBytes': totalBytes,
    'currentName': currentName,
    'currentKind': currentKind.name,
  };

  @override
  bool operator ==(Object other) =>
      other is TransferActivitySnapshot &&
      other.structuralKey == structuralKey &&
      other.currentKind == currentKind &&
      other.progress == progress &&
      other.completedBytes == completedBytes &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode =>
      Object.hash(structuralKey, currentKind, progress, completedBytes);

  /// Changes that must reach the Lock Screen immediately; byte and percent
  /// movement alone is throttled.
  Object get structuralKey =>
      (phase, source, totalCount, completedCount, failedCount, currentName);
}

typedef TransferActivityAlert = ({String title, String body});

/// Drives TeleDrive's single upload Live Activity on iOS (Lock Screen,
/// Dynamic Island, StandBy). One activity per upload session, per the HIG:
/// it starts with the session, updates only on new content, and ends as
/// soon as the queue settles. Every failure is soft — uploads never depend
/// on the activity, and unsupported platforms are inert.
class TransferLiveActivityService {
  TransferLiveActivityService({
    this._channel = const MethodChannel('teledrive/live-activity'),
    bool? platformSupported,
    this.progressInterval = const Duration(seconds: 1),
    this.heartbeatInterval = const Duration(seconds: 60),
    this.startRetryInterval = const Duration(seconds: 30),
  }) : _platformAllowed =
           platformSupported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    if (_platformAllowed) _channel.setMethodCallHandler(_handleNativeCall);
  }

  static final TransferLiveActivityService instance =
      TransferLiveActivityService();

  /// For callers (and tests) that must never touch ActivityKit.
  static final TransferLiveActivityService disabled =
      TransferLiveActivityService(platformSupported: false);

  /// Minimum spacing of percent-only updates.
  final Duration progressInterval;

  /// Re-send while running so the native stale date (150 s) only passes
  /// when TeleDrive has really stopped.
  final Duration heartbeatInterval;

  /// Back-off after a refused start (disabled, background, system limit).
  final Duration startRetryInterval;

  /// Time the outcome stays in the Dynamic Island before the activity ends.
  static const lingerSeconds = 4;

  final MethodChannel _channel;
  final bool _platformAllowed;

  /// Bumped when the person taps the activity; the shell opens the upload
  /// panel in response.
  final ValueNotifier<int> openTransfersRequests = ValueNotifier(0);

  Future<bool>? _supported;
  Future<void> _tail = Future.value();

  String? _session;
  bool _confirmed = false;
  String? _declinedSession;
  DateTime? _sessionStartedAt;
  DateTime? _nextStartAttempt;
  TransferActivitySnapshot? _lastSent;
  DateTime? _lastSentAt;
  TransferActivitySnapshot? _latest;
  Timer? _trailing;
  Timer? _heartbeat;

  /// Whether an activity is (being) shown for [sessionId].
  bool isTracking(String sessionId) => _session == sessionId;

  /// Whether this OS can show Live Activities; resolved once.
  Future<bool> get isSupported {
    if (!_platformAllowed) return Future.value(false);
    return _supported ??= _invoke<Map<Object?, Object?>>('status').then((
      status,
    ) {
      return knownSupported = status?['supported'] == true;
    });
  }

  /// Last resolved [isSupported], for a first frame without a flash.
  bool? knownSupported;

  /// Mirrors the upload queue. Call on every queue change; this decides
  /// whether ActivityKit hears about it.
  void sync({
    required String? sessionId,
    required TransferActivitySnapshot? snapshot,
    required bool enabled,
  }) {
    if (!_platformAllowed) return;
    if (!enabled || sessionId == null || snapshot == null) {
      if (_session != null) _endCurrent();
      return;
    }
    if (_session != null && _session != sessionId) _endCurrent();
    // finish() owns the outcome so it can carry the alert and dismissal.
    if (snapshot.isTerminal) return;
    if (_declinedSession == sessionId) return;
    _latest = snapshot;
    if (_session == null) {
      _start(sessionId, snapshot);
      return;
    }
    _scheduleUpdate();
  }

  /// Ends the session's activity with its outcome. Returns whether the
  /// activity delivered [alert], so the caller can skip a duplicate local
  /// notification (HIG: don't notify twice for the same update).
  Future<bool> finish({
    required String sessionId,
    required TransferActivitySnapshot snapshot,
    required bool foreground,
    TransferActivityAlert? alert,
  }) async {
    if (!_platformAllowed || _session != sessionId) return false;
    final startedAt = _sessionStartedAt;
    _resetSession();
    // In the foreground the upload panel already showed the outcome; a
    // lingering Lock Screen card would only be clutter.
    final dismissAfter = foreground
        ? 0
        : dismissalSeconds(snapshot.phase, startedAt: startedAt);
    final deliverAlert =
        foreground || snapshot.phase == TransferActivityPhase.cancelled
        ? null
        : alert;
    final ended = await _enqueue(
      () => _invoke<bool>('end', {
        'sessionId': sessionId,
        'state': snapshot.toMap(),
        'lingerSeconds':
            foreground || snapshot.phase == TransferActivityPhase.cancelled
            ? 0
            : lingerSeconds,
        'dismissAfterSeconds': dismissAfter,
        if (deliverAlert != null) 'alertTitle': deliverAlert.title,
        if (deliverAlert != null) 'alertBody': deliverAlert.body,
      }),
    );
    return ended == true && deliverAlert != null;
  }

  /// HIG: keep an ended activity's summary proportional to the task — 15 to
  /// 30 minutes covers most cases, shorter for quick uploads, longer when
  /// something needs attention.
  @visibleForTesting
  static int dismissalSeconds(
    TransferActivityPhase phase, {
    DateTime? startedAt,
    DateTime? now,
  }) {
    switch (phase) {
      case TransferActivityPhase.cancelled:
        return 0;
      case TransferActivityPhase.failed:
      case TransferActivityPhase.partial:
        return 30 * 60;
      default:
        final elapsed = startedAt == null
            ? Duration.zero
            : (now ?? DateTime.now()).difference(startedAt);
        return elapsed.inSeconds.clamp(2 * 60, 15 * 60);
    }
  }

  void _start(String sessionId, TransferActivitySnapshot snapshot) {
    final now = DateTime.now();
    final next = _nextStartAttempt;
    if (next != null && now.isBefore(next)) return;
    _nextStartAttempt = now.add(startRetryInterval);
    _session = sessionId;
    _confirmed = false;
    _sessionStartedAt ??= now;
    _markSent(snapshot);
    unawaited(
      _enqueue(() async {
        if (!await isSupported) return false;
        return _invoke<bool>('start', {
          'sessionId': sessionId,
          'state': snapshot.toMap(),
        });
      }).then((started) {
        if (_session != sessionId) return;
        if (started == true) {
          _confirmed = true;
          _nextStartAttempt = null;
          _startHeartbeat();
        } else {
          // Disabled in Settings, started from the background, or at the
          // system limit: retry later; uploads carry on regardless.
          _session = null;
        }
      }),
    );
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _send());
    // Progress may have moved while the request was in flight.
    if (_latest != null && _latest != _lastSent) _send();
  }

  void _scheduleUpdate() {
    final latest = _latest;
    final last = _lastSent;
    if (latest == null || !_confirmed) return;
    if (last == null || latest.structuralKey != last.structuralKey) {
      _send();
      return;
    }
    if (latest.percent == last.percent) return;
    final elapsed = DateTime.now().difference(_lastSentAt ?? DateTime(0));
    if (elapsed >= progressInterval) {
      _send();
    } else if (_trailing?.isActive != true) {
      _trailing = Timer(progressInterval - elapsed, _send);
    }
  }

  void _send() {
    final sessionId = _session;
    final snapshot = _latest;
    if (sessionId == null || snapshot == null || !_confirmed) return;
    _trailing?.cancel();
    _markSent(snapshot);
    unawaited(
      _enqueue(
        () => _invoke<bool>('update', {
          'sessionId': sessionId,
          'state': snapshot.toMap(),
        }),
      ).then((live) {
        if (live != false || _session != sessionId) return;
        // Removed by the person: respect it for the rest of the session.
        _declinedSession = sessionId;
        _resetSession();
      }),
    );
  }

  void _markSent(TransferActivitySnapshot snapshot) {
    _lastSent = snapshot;
    _lastSentAt = DateTime.now();
  }

  void _endCurrent() {
    final sessionId = _session;
    _resetSession();
    if (sessionId == null) return;
    unawaited(
      _enqueue(
        () => _invoke<bool>('end', {
          'sessionId': sessionId,
          'state': (_lastSentOrEmpty(sessionId)).toMap(),
          'dismissAfterSeconds': 0,
        }),
      ),
    );
  }

  TransferActivitySnapshot _lastSentOrEmpty(String sessionId) =>
      _lastSent ??
      const TransferActivitySnapshot(
        phase: TransferActivityPhase.cancelled,
        source: TransferActivitySource.uploads,
        totalCount: 0,
        completedCount: 0,
        failedCount: 0,
        progress: 0,
        completedBytes: 0,
        totalBytes: 0,
      );

  void _resetSession() {
    _session = null;
    _confirmed = false;
    _sessionStartedAt = null;
    _nextStartAttempt = null;
    _latest = null;
    _trailing?.cancel();
    _trailing = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<T?> _enqueue<T>(Future<T?> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Live Activity $method failed: ${error.message}');
      return null;
    } on MissingPluginException {
      knownSupported = false;
      _supported = Future.value(false);
      return null;
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openTransfers') openTransfersRequests.value++;
    return null;
  }
}
