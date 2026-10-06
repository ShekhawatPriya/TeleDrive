import 'package:flutter/services.dart';

/// Retained only for the lifetime of one Photos viewer session.
class PhotoPlaybackMemory {
  Duration position = Duration.zero;
  bool muted = true;
  bool userPaused = false;
  String? revision;
  void resetFor(String value) {
    if (revision == value) return;
    revision = value;
    position = Duration.zero;
    muted = true;
    userPaused = false;
  }
}

class PhotoPlaybackEvent {
  const PhotoPlaybackEvent({
    required this.ready,
    required this.buffering,
    required this.position,
    required this.duration,
    required this.muted,
    required this.userPaused,
    this.dimensions,
    this.error,
  });
  factory PhotoPlaybackEvent.fromMap(
    Map<Object?, Object?> data,
  ) => PhotoPlaybackEvent(
    ready: data['ready'] == true,
    buffering: data['buffering'] == true,
    position: Duration(milliseconds: (data['positionMs'] as num? ?? 0).toInt()),
    duration: Duration(milliseconds: (data['durationMs'] as num? ?? 0).toInt()),
    muted: data['muted'] != false,
    userPaused: data['userPaused'] == true,
    dimensions:
        (data['width'] as num? ?? 0) > 0 && (data['height'] as num? ?? 0) > 0
        ? Size(
            (data['width'] as num).toDouble(),
            (data['height'] as num).toDouble(),
          )
        : null,
    error: data['error'] as String?,
  );
  final bool ready, buffering, muted, userPaused;
  final Duration position, duration;
  final Size? dimensions;
  final String? error;
}

/// The native engine receives a resolved source and opaque session ID only.
/// Account/Telegram resolution belongs to the Dart media service.
class NativePhotoPlayback {
  NativePhotoPlayback(
    int viewId, {
    required this.session,
    required this.onEvent,
    this.onDrag,
    this.onPageDrag,
    this.onTap,
    this.onPage,
    this.onFullscreen,
  }) : _channel = MethodChannel('teledrive/photo-video/$viewId') {
    _channel.setMethodCallHandler(_event);
  }
  final String session;
  final ValueChanged<PhotoPlaybackEvent> onEvent;
  final void Function(String phase, Offset point, Offset velocity)? onDrag,
      onPageDrag;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPage, onFullscreen;
  final MethodChannel _channel;
  bool _disposed = false;
  Future<void> _event(MethodCall call) async {
    final data = call.arguments;
    if (_disposed || data is! Map || data['session'] != session) return;
    if (call.method == 'state') onEvent(PhotoPlaybackEvent.fromMap(data));
    if (call.method == 'page') onPage?.call(data['forward'] == true);
    if (call.method == 'fullscreen') onFullscreen?.call(data['value'] == true);
    if (call.method == 'tap') onTap?.call();
    if (call.method == 'drag')
      (data['axis'] == 'horizontal' ? onPageDrag : onDrag)?.call(
        '${data['phase']}',
        Offset(
          (data['x'] as num? ?? 0).toDouble(),
          (data['y'] as num? ?? 0).toDouble(),
        ),
        Offset(
          (data['dx'] as num? ?? 0).toDouble(),
          (data['dy'] as num? ?? 0).toDouble(),
        ),
      );
  }

  Future<void> command(
    String method, [
    Map<String, Object?> values = const {},
  ]) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>(method, {
        'session': session,
        ...values,
      });
    } on MissingPluginException {
      /* A removed platform view has no receiver. */
    } on PlatformException {
      /* Native playback errors arrive through state. */
    }
  }

  Future<void> setActive(bool value) => command('active', {'value': value});
  Future<void> seek(Duration position) =>
      command('seek', {'positionMs': position.inMilliseconds});
  Future<void> mute(bool value) => command('mute', {'value': value});
  Future<void> pause() => command('pause');
  void dispose() {
    if (_disposed) return;
    command('dispose');
    _disposed = true;
    _channel.setMethodCallHandler(null);
  }
}
