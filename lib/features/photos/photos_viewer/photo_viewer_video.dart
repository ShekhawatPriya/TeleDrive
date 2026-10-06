import 'dart:async';
import 'dart:io';
import 'package:chewie/chewie.dart';
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
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

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
    this.onFullscreen,
    this.onNativeChanged,
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
  final ValueChanged<bool>? onNativePage, onFullscreen, onNativeChanged;
  @override
  ConsumerState<PhotoViewerVideo> createState() => _PhotoViewerVideoState();
}

class _PhotoViewerVideoState extends ConsumerState<PhotoViewerVideo>
    with WidgetsBindingObserver {
  final _ownMemory = PhotoPlaybackMemory();
  PhotoPlaybackMemory get _memory => widget.memory ?? _ownMemory;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  NativePhotoPlayback? _native;
  CancelToken? _cancel;
  int _generation = 0;
  String? _source, _revision, _error;
  bool _ready = false,
      _buffering = false,
      _foreground = true,
      _nativeSupported = false;
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
          await video.setVolume(_memory.muted ? 0 : 1);
          await video.seekTo(_memory.position);
          if (!mounted || generation != _generation || !_active) {
            await video.dispose();
            return;
          }
          _video = video;
          video.addListener(_fallbackState);
          _chewie = ChewieController(
            videoPlayerController: video,
            autoPlay: false,
            looping: false,
            allowFullScreen: true,
          );
          setState(() {
            _source = source;
            _ready = true;
          });
          _reportDimensions(video.value.size);
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
    _memory.position = video.value.position;
    _memory.muted = video.value.volume == 0;
    if (_active && !_programmatic && !video.value.isBuffering)
      _memory.userPaused = !video.value.isPlaying;
    if (video.value.hasError && _error == null && mounted)
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
    _chewie?.dispose();
    _video?.dispose();
    _video = null;
    _chewie = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _cancel?.cancel();
    _native?.dispose();
    _disposeFallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final native = _useNative && source != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_ready || _error != null)
          Center(
            child: MediaThumb(
              file: widget.file,
              fit: BoxFit.contain,
              radius: 0,
              decodeWidth: 960,
            ),
          ),
        if (native && _error == null)
          Padding(
            key: const ValueKey('photo-native-player-host'),
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 48,
              bottom: MediaQuery.paddingOf(context).bottom + 120,
            ),
            child: UiKitView(
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
                _native = NativePhotoPlayback(
                  id,
                  session: '$_revision:$_generation',
                  onEvent: (event) {
                    _memory.position = event.position;
                    _memory.muted = event.muted;
                    _memory.userPaused = event.userPaused;
                    _reportDimensions(event.dimensions);
                    if (_ready != event.ready ||
                        _buffering != event.buffering ||
                        event.error != _error) {
                      setState(() {
                        _ready = event.ready;
                        _buffering = event.buffering;
                        _error = event.error;
                      });
                    }
                  },
                  onDrag: widget.onNativeDrag,
                  onPageDrag: widget.onNativePageDrag,
                  onTap: widget.onTap,
                  onPage: widget.onNativePage,
                  onFullscreen: widget.onFullscreen,
                );
                _native!.command('status');
                _native!.setActive(_active);
              },
            ),
          ),
        if (!native && _chewie != null && _error == null)
          Chewie(controller: _chewie!),
        if (_error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, style: const TextStyle(color: Colors.white)),
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
    );
  }
}
