import 'package:flutter/services.dart';
import 'package:flutter_m_fsdk/core/notifications/transfer_live_activity_service.dart';
import 'package:flutter_m_fsdk/features/upload/upload_live_activity.dart';
import 'package:flutter_m_fsdk/features/upload/upload_models.dart';
import 'package:flutter_test/flutter_test.dart';

UploadItem _item(
  String id,
  UploadStatus status, {
  String name = 'IMG_0001.HEIC',
  String mime = 'image/heic',
  int size = 1000,
  double server = 0,
  String source = 'manual_picker',
}) => UploadItem(
  localId: id,
  uploadClientId: 'client-$id',
  name: name,
  size: size,
  mimeType: mime,
  path: '/fixture/$id',
  status: status,
  serverProgress: server,
  clientSource: source,
);

TransferActivitySnapshot _snapshot({
  TransferActivityPhase phase = TransferActivityPhase.uploading,
  int completed = 0,
  double progress = 0.2,
  String? name = 'a.jpg',
}) => TransferActivitySnapshot(
  phase: phase,
  source: TransferActivitySource.uploads,
  totalCount: 3,
  completedCount: completed,
  failedCount: 0,
  progress: progress,
  completedBytes: (progress * 3000).round(),
  totalBytes: 3000,
  currentName: name,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('uploadActivitySnapshot', () {
    test('stays off the Lock Screen until uploads are confirmed', () {
      expect(uploadActivitySnapshot(const []), isNull);
      expect(
        uploadActivitySnapshot([_item('a', UploadStatus.selected)]),
        isNull,
      );
    });

    test('reports preparing before any bytes reach Telegram', () {
      final snapshot = uploadActivitySnapshot([
        _item('a', UploadStatus.preparingMetadata),
        _item('b', UploadStatus.queued),
      ])!;
      expect(snapshot.phase, TransferActivityPhase.preparing);
      expect(snapshot.totalCount, 2);
      expect(snapshot.currentKind, TransferActivityFileKind.image);
    });

    test('names the file in flight and real session counts', () {
      final snapshot = uploadActivitySnapshot([
        _item('a', UploadStatus.uploaded),
        _item(
          'b',
          UploadStatus.uploadingOriginalToTelegram,
          name: 'Report.pdf',
          mime: 'application/pdf',
          server: 0.5,
        ),
        _item('c', UploadStatus.queued),
      ])!;
      expect(snapshot.phase, TransferActivityPhase.uploading);
      expect(snapshot.completedCount, 1);
      expect(snapshot.currentName, 'Report.pdf');
      expect(snapshot.currentKind, TransferActivityFileKind.document);
      expect(snapshot.totalBytes, 3000);
      // (1000 + 500 + 0) / 3000 bytes, the same count as the in-app panel.
      expect(snapshot.progress, closeTo(0.5, 0.001));
      expect(snapshot.percent, 50);
    });

    test('preview generation after the original landed is uploading', () {
      final snapshot = uploadActivitySnapshot([
        _item('a', UploadStatus.creatingThumbnail),
      ])!;
      expect(snapshot.phase, TransferActivityPhase.uploading);
      expect(snapshot.completedBytes, snapshot.totalBytes);
    });

    test('waits for Wi-Fi only when nothing else can move', () {
      expect(
        uploadActivitySnapshot([
          _item('a', UploadStatus.uploaded),
          _item('b', UploadStatus.waitingForWifi),
        ])!.phase,
        TransferActivityPhase.waitingForWifi,
      );
      expect(
        uploadActivitySnapshot([
          _item('a', UploadStatus.uploadingOriginalToTelegram),
          _item('b', UploadStatus.waitingForWifi),
        ])!.phase,
        TransferActivityPhase.uploading,
      );
    });

    test('classifies every settled outcome', () {
      TransferActivityPhase phase(List<UploadStatus> statuses) =>
          uploadActivitySnapshot([
            for (var i = 0; i < statuses.length; i++) _item('$i', statuses[i]),
          ])!.phase;
      expect(phase([UploadStatus.uploaded]), TransferActivityPhase.completed);
      expect(
        phase([UploadStatus.uploaded, UploadStatus.failed]),
        TransferActivityPhase.partial,
      );
      expect(
        phase([UploadStatus.failed, UploadStatus.cancelled]),
        TransferActivityPhase.failed,
      );
      expect(phase([UploadStatus.cancelled]), TransferActivityPhase.cancelled);
    });

    test('settled sessions drop the file name', () {
      final snapshot = uploadActivitySnapshot([
        _item('a', UploadStatus.uploaded),
      ])!;
      expect(snapshot.currentName, isNull);
      expect(snapshot.toMap()['currentName'], isNull);
    });

    test('labels photo backup only when every item is backup', () {
      expect(
        uploadActivitySnapshot([
          _item('a', UploadStatus.queued, source: 'gallery_backup'),
        ])!.source,
        TransferActivitySource.backup,
      );
      expect(
        uploadActivitySnapshot([
          _item('a', UploadStatus.queued, source: 'gallery_backup'),
          _item('b', UploadStatus.queued),
        ])!.source,
        TransferActivitySource.uploads,
      );
    });
  });

  group('TransferLiveActivityService', () {
    const channel = MethodChannel('teledrive/live-activity-test');
    late List<MethodCall> calls;
    late bool updateResult;
    late bool startResult;
    late TransferLiveActivityService service;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() {
      calls = [];
      updateResult = true;
      startResult = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'status' => {'supported': true, 'enabled': true},
          'start' => startResult,
          'update' => updateResult,
          _ => true,
        };
      });
      service = TransferLiveActivityService(
        channel: channel,
        platformSupported: true,
        progressInterval: const Duration(milliseconds: 80),
        heartbeatInterval: const Duration(milliseconds: 150),
        startRetryInterval: const Duration(milliseconds: 120),
      );
    });

    tearDown(() async {
      // Stop heartbeats so one test's timers never reach the next test.
      service.sync(sessionId: null, snapshot: null, enabled: true);
      await pumpEventQueue();
      messenger.setMockMethodCallHandler(channel, null);
    });

    Future<void> settle() => pumpEventQueue();
    Future<void> wait(int ms) =>
        Future<void>.delayed(Duration(milliseconds: ms)).then((_) => settle());

    List<String> methods() => [
      for (final call in calls)
        if (call.method != 'status') call.method,
    ];

    Map<Object?, Object?> state(MethodCall call) =>
        (call.arguments as Map)['state'] as Map<Object?, Object?>;

    test('starts once, then sends structural changes immediately', () async {
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      await settle();
      expect(methods(), ['start']);
      expect(service.isTracking('s1'), isTrue);

      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(completed: 1, name: 'b.jpg'),
        enabled: true,
      );
      await settle();
      expect(methods(), ['start', 'update']);
      expect(state(calls.last)['completedCount'], 1);
      expect(state(calls.last)['currentName'], 'b.jpg');
      service.sync(sessionId: 's1', snapshot: null, enabled: true);
      await settle();
    });

    test('throttles percent-only movement to one update per second', () async {
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      await settle();
      await wait(100);
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(progress: 0.25),
        enabled: true,
      );
      await settle();
      expect(methods(), ['start', 'update']);

      // Same percent: nothing new to say.
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(progress: 0.2549),
        enabled: true,
      );
      // Newer percents inside the window collapse into one trailing send.
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(progress: 0.30),
        enabled: true,
      );
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(progress: 0.35),
        enabled: true,
      );
      await settle();
      expect(methods(), ['start', 'update']);
      await wait(100);
      expect(methods(), ['start', 'update', 'update']);
      expect(state(calls.last)['progress'], 0.35);
      service.sync(sessionId: 's1', snapshot: null, enabled: true);
      await settle();
    });

    test(
      'heartbeat keeps a quiet but running activity from going stale',
      () async {
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await settle();
        await wait(170);
        expect(methods(), ['start', 'update']);
        service.sync(sessionId: 's1', snapshot: null, enabled: true);
        await settle();
        await wait(170);
        expect(methods(), ['start', 'update', 'end']);
      },
    );

    test('respects removal from the Lock Screen for the session', () async {
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      await settle();
      updateResult = false;
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(completed: 1),
        enabled: true,
      );
      await settle();
      expect(service.isTracking('s1'), isFalse);
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(completed: 2),
        enabled: true,
      );
      await settle();
      expect(methods(), ['start', 'update']);

      service.sync(sessionId: 's2', snapshot: _snapshot(), enabled: true);
      await settle();
      expect(methods().last, 'start');
      expect((calls.last.arguments as Map)['sessionId'], 's2');
    });

    test(
      'a failed start retries later instead of every queue change',
      () async {
        startResult = false;
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await settle();
        expect(service.isTracking('s1'), isFalse);
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await settle();
        expect(methods(), ['start']);
        startResult = true;
        await wait(140);
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await settle();
        expect(methods(), ['start', 'start']);
        expect(service.isTracking('s1'), isTrue);
        service.sync(sessionId: 's1', snapshot: null, enabled: true);
        await settle();
      },
    );

    test('turning the setting off ends the activity immediately', () async {
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      await settle();
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: false);
      await settle();
      expect(methods(), ['start', 'end']);
      expect((calls.last.arguments as Map)['dismissAfterSeconds'], 0);
    });

    test('terminal snapshots wait for finish to carry the outcome', () async {
      service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      await settle();
      service.sync(
        sessionId: 's1',
        snapshot: _snapshot(phase: TransferActivityPhase.completed),
        enabled: true,
      );
      await settle();
      expect(methods(), ['start']);
      expect(service.isTracking('s1'), isTrue);
      service.sync(sessionId: 's1', snapshot: null, enabled: true);
      await settle();
    });

    test(
      'background finish delivers the alert, lingers, and keeps a summary',
      () async {
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await pumpEventQueue();
        final delivered = await service.finish(
          sessionId: 's1',
          snapshot: _snapshot(
            phase: TransferActivityPhase.completed,
            completed: 3,
            progress: 1,
            name: null,
          ),
          foreground: false,
          alert: (title: 'Upload complete', body: '3 files uploaded.'),
        );
        expect(delivered, isTrue);
        expect(service.isTracking('s1'), isFalse);
        final end = calls.last.arguments as Map;
        expect(calls.last.method, 'end');
        expect(end['alertTitle'], 'Upload complete');
        expect(end['lingerSeconds'], TransferLiveActivityService.lingerSeconds);
        expect(end['dismissAfterSeconds'], 120);
        expect(state(calls.last)['phase'], 'completed');
      },
    );

    test(
      'foreground finish ends at once and leaves alerts to the app',
      () async {
        service.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
        await pumpEventQueue();
        final delivered = await service.finish(
          sessionId: 's1',
          snapshot: _snapshot(phase: TransferActivityPhase.failed),
          foreground: true,
          alert: (
            title: 'Upload failed',
            body: '1 file could not be uploaded.',
          ),
        );
        expect(delivered, isFalse);
        final end = calls.last.arguments as Map;
        expect(end.containsKey('alertTitle'), isFalse);
        expect(end['lingerSeconds'], 0);
        expect(end['dismissAfterSeconds'], 0);
      },
    );

    test('finish without a tracked activity is a no-op', () async {
      final delivered = await service.finish(
        sessionId: 'unknown',
        snapshot: _snapshot(phase: TransferActivityPhase.completed),
        foreground: false,
      );
      expect(delivered, isFalse);
      expect(calls, isEmpty);
    });

    test('tapping the activity requests the upload panel', () async {
      final before = service.openTransfersRequests.value;
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('openTransfers')),
        (_) {},
      );
      expect(service.openTransfersRequests.value, before + 1);
    });

    test('dismissal time is proportional and bounded', () {
      final now = DateTime(2026, 10, 16, 12);
      int seconds(TransferActivityPhase phase, Duration elapsed) =>
          TransferLiveActivityService.dismissalSeconds(
            phase,
            startedAt: now.subtract(elapsed),
            now: now,
          );
      expect(
        seconds(TransferActivityPhase.completed, const Duration(seconds: 20)),
        120,
      );
      expect(
        seconds(TransferActivityPhase.completed, const Duration(minutes: 7)),
        420,
      );
      expect(
        seconds(TransferActivityPhase.completed, const Duration(hours: 2)),
        900,
      );
      expect(seconds(TransferActivityPhase.partial, Duration.zero), 1800);
      expect(seconds(TransferActivityPhase.cancelled, Duration.zero), 0);
    });

    test('unsupported platforms never touch the channel', () {
      final inert = TransferLiveActivityService(
        channel: channel,
        platformSupported: false,
      );
      inert.sync(sessionId: 's1', snapshot: _snapshot(), enabled: true);
      expect(inert.isTracking('s1'), isFalse);
      expect(calls, isEmpty);
    });
  });
}
