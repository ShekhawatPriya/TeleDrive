import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../core/media/media_source_resolver.dart';
import '../../../core/media/photo_media_loader.dart';
import '../../../core/media/photo_playback.dart';
import '../../../core/media/photo_video_controller.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

/// One video page. The video fills the page (fitted, or filled after a
/// double-tap) and draws no controls of its own: the viewer's chrome shows the
/// transport through [onPlayback], so a tap shows or hides everything at once.
class PhotoViewerVideo extends ConsumerStatefulWidget {
  const PhotoViewerVideo({
    required this.file,
    required this.isActive,
    required this.onTap,
    this.memory,
    this.onDimensions,
    this.onNativeDrag,
    this.onNativePage,
    this.onNativePageDrag,
    this.onNativeChanged,
    this.onPlayback,
    super.key,
  });
  final DriveFile file;
  final bool isActive;
  final VoidCallback onTap;
  final PhotoPlaybackMemory? memory;
  final ValueChanged<Size>? onDimensions;
  final void Function(
    String phase,
    Offset position,
    Offset velocity,
  )? onNativeDrag,
      onNativePageDrag;
  final ValueChanged<bool>? onNativePage, onNativeChanged;

  /// Reports this page's controller (`attached`) and its removal.
  final void Function(PhotoVideoController controller, bool attached)?
  onPlayback;
  @override
  ConsumerState<PhotoViewerVideo> createState() => _PhotoViewerVideoState();
}

class _PhotoViewerVideoState extends ConsumerState<PhotoViewerVideo>
    with WidgetsBindingObserver {
  final _ownMemory = PhotoPlaybackMemory();
  PhotoPlaybackMemory get _memory => widget.memory ?? _ownMemory;
  final _controller = PhotoVideoController();
  VideoPlayerController? _video;
  NativePhotoPlayback? _native;
  CancelToken? _cancel;
  int _generation = 0;
  String? _source, _revision, _error;
  bool _ready = false, _foreground = true, _nativeSupported = false;
  bool _programmatic = false;
  double? _progress;
  Size? _dimensions;
  bool get _active => widget.isActive && _foreground;
  bool get _useNative =>
      _nativeSupported && Theme.of(context).platform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.report(PhotoVideoState(muted: _memory.muted));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPlayback?.call(_controller, true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = ref.read(photoMediaLoaderProvider).revision(widget.file);
    if (revision != _revision) {
      _reset(revision);
    }
  }

  @override
  void didUpdateWidget(PhotoViewerVideo old) {
    super.didUpdateWidget(old);
    final revision = ref.read(photoMediaLoaderProvider).revision(widget.file);
    if (revision != _revision) {
      _reset(revision);
      return;
    }
    if (_active) {
      if (_source == null && _cancel == null && _error == null) _prepare();
    } else if (_source == null) {
      _generation++;
      _cancel?.cancel();
      _cancel = null;
    }
    _setActive();
  }

  void _reset(String revision) {
    _generation++;
    _cancel?.cancel();
    _cancel = null;
    _native?.dispose();
    _native = null;
    _disposeFallback();
    _source = null;
    _ready = false;
    _error = null;
    _revision = revision;
    _memory.resetFor(revision);
    _controller.engine = null;
    // Runs during build; the chrome listening to the controller is elsewhere
    // in the tree, so it hears about the new revision after this frame.
    final muted = _memory.muted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.report(PhotoVideoState(muted: muted));
    });
    if (_active) _prepare();
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      var supports = false;
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        try {
          supports =
              await const MethodChannel(
                'teledrive/appearance',
              ).invokeMethod<bool>('supportsPhotoVideo') ??
              false;
        } on MissingPluginException {
          supports = false;
        } on PlatformException {
          supports = false;
        }
      }
      if (!mounted || generation != _generation || !_active) return;
      final source = await ref
          .read(photoMediaLoaderProvider)
          .video(
            widget.file,
            cancel,
            progress: (done, total) {
              if (mounted && generation == _generation)
                setState(() => _progress = total > 0 ? done / total : null);
            },
          );
      if (!mounted || generation != _generation || !_active) return;
      if (supports) {
        setState(() {
          _nativeSupported = true;
          _source = source;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onNativeChanged?.call(true);
        });
      } else {
        final video = MediaSourceResolver.isLocalPath(source)
            ? VideoPlayerController.file(File(source))
            : VideoPlayerController.networkUrl(Uri.parse(source));
        try {
          await video.initialize();
          if (!mounted || generation != _generation || !_active) {
            await video.dispose();
            return;
          }
          // Videos loop, as with Photos' Loop Videos setting.
          await video.setLooping(true);
          await video.setVolume(_memory.muted ? 0 : 1);
          await video.seekTo(_memory.position);
          if (!mounted || generation != _generation || !_active) {
            await video.dispose();
            return;
          }
          _video = video;
          video.addListener(_fallbackState);
          _controller.engine = _FallbackEngine(video, _fill);
          setState(() {
            _source = source;
            _ready = true;
          });
          _reportDimensions(video.value.size);
          _fallbackState();
          _setActive();
        } catch (_) {
          await video.dispose();
          rethrow;
        }
      }
    } catch (_) {
      if (mounted && generation == _generation && !cancel.isCancelled)
        setState(() => _error = 'Could not play this video.');
    } finally {
      if (generation == _generation) _cancel = null;
    }
  }

  void _fill(bool value) {
    if (mounted) setState(() {});
  }

  void _reportDimensions(Size? value) {
    if (value == null || value.isEmpty || value == _dimensions) return;
    _dimensions = value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDimensions?.call(value);
    });
  }

  void _fallbackState() {
    final video = _video;
    if (video == null) return;
    final state = video.value;
    _memory.position = state.position;
    _memory.muted = state.volume == 0;
    if (_active && !_programmatic && !state.isBuffering)
      _memory.userPaused = !state.isPlaying;
    _controller.report(
      PhotoVideoState(
        ready: state.isInitialized,
        playing: state.isPlaying,
        buffering: state.isBuffering,
        muted: state.volume == 0,
        filled: _controller.value.filled,
        position: state.position,
        duration: state.duration,
      ),
    );
    if (state.hasError && _error == null && mounted)
      setState(() => _error = 'Could not play this video.');
  }

  void _setActive() {
    _native?.setActive(_active);
    final video = _video;
    if (video == null) return;
    _programmatic = true;
    final operation = _active && !_memory.userPaused
        ? video.play()
        : video.pause();
    operation.whenComplete(() => _programmatic = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _source == null) {
      _generation++;
      _cancel?.cancel();
      _cancel = null;
    }
    _setActive();
    if (_active && _source == null && _cancel == null && _error == null)
      _prepare();
  }

  void _disposeFallback() {
    _video?.removeListener(_fallbackState);
    _video?.dispose();
    _video = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _cancel?.cancel();
    _native?.dispose();
    _disposeFallback();
    _controller.engine = null;
    widget.onPlayback?.call(_controller, false);
    final controller = _controller;
    // The chrome may still be listening during this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final native = _useNative && source != null;
    final video = _video;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: _ready && _error == null ? _controller.toggleFill : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_ready || _error != null)
            Center(
              child: MediaThumb(
                file: widget.file,
                fit: BoxFit.contain,
                radius: 0,
                decodeWidth: 960,
                showBackground: false,
              ),
            ),
          if (native && _error == null)
            UiKitView(
              key: ValueKey('$_revision:$_generation'),
              viewType: 'teledrive/photo-video',
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              creationParamsCodec: const StandardMessageCodec(),
              creationParams: {
                'source': source,
                'session': '$_revision:$_generation',
                'active': _active,
                'muted': _memory.muted,
                'userPaused': _memory.userPaused,
                'positionMs': _memory.position.inMilliseconds,
              },
              onPlatformViewCreated: (id) {
                if (!mounted) return;
                _native?.dispose();
                final native = NativePhotoPlayback(
                  id,
                  session: '$_revision:$_generation',
                  onEvent: (event) {
                    _memory.position = event.position;
                    _memory.muted = event.muted;
                    _memory.userPaused = event.userPaused;
                    _reportDimensions(event.dimensions);
                    _controller.report(
                      PhotoVideoState(
                        ready: event.ready,
                        playing: event.playing,
                        buffering: event.buffering,
                        muted: event.muted,
                        filled: event.filled,
                        position: event.position,
                        duration: event.duration,
                      ),
                    );
                    if (_ready != event.ready || event.error != _error) {
                      setState(() {
                        _ready = event.ready;
                        _error = event.error;
                      });
                    }
                  },
                  onDrag: widget.onNativeDrag,
                  onPageDrag: widget.onNativePageDrag,
                  onTap: widget.onTap,
                  onPage: widget.onNativePage,
                );
                _native = native;
                _controller.engine = native;
                native.command('status');
                native.setActive(_active);
              },
            ),
          if (!native && video != null && _error == null)
            SizedBox.expand(
              child: FittedBox(
                key: const ValueKey('photo-fallback-player'),
                fit: _controller.value.filled ? BoxFit.cover : BoxFit.contain,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: video.value.size.width,
                  height: video.value.size.height,
                  child: VideoPlayer(video),
                ),
              ),
            ),
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF8E8E93)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _reset(_revision!));
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            )
          else if (!_ready && _active)
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator.adaptive(
                    value: _progress,
                    semanticsLabel: 'Preparing video',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// video_player behind the shared transport on Android and bridge-less hosts.
class _FallbackEngine implements PhotoVideoEngine {
  _FallbackEngine(this.video, this.onFill);
  final VideoPlayerController video;
  final ValueChanged<bool> onFill;
  @override
  Future<void> play() async {
    final value = video.value;
    if (value.duration > Duration.zero && value.position >= value.duration)
      await video.seekTo(Duration.zero);
    await video.play();
  }

  @override
  Future<void> pause() => video.pause();
  @override
  Future<void> seek(Duration position, {bool exact = true}) =>
      video.seekTo(position);
  @override
  Future<void> mute(bool value) => video.setVolume(value ? 0 : 1);
  @override
  Future<void> fill(bool value) async => onFill(value);
}
