import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/media/thumbnail_loader.dart';
import '../core/media/media_source_resolver.dart';
import '../core/media/thumbnail_scheduler.dart';
import '../models/drive_models.dart';
import 'google_drive_icon.dart';
import 'thumbnail_visibility.dart';

class MediaThumb extends ConsumerStatefulWidget {
  const MediaThumb({
    required this.file,
    this.fit = BoxFit.contain,
    this.radius = 18,
    this.showBackground = true,
    this.decodeWidth = 320,
    super.key,
  });

  final DriveFile file;
  final BoxFit fit;
  final double radius;
  final bool showBackground;
  final int decodeWidth;

  @override
  ConsumerState<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends ConsumerState<MediaThumb> {
  ThumbnailLoader? _loader;
  ThumbnailRequest<File>? _request;
  ThumbnailPriority? _priority;
  String? _key;
  File? _file;
  Timer? _retry;
  int _attempt = 0;
  int _generation = 0;
  bool _failed = false;
  bool _original = false;
  bool _checkingCache = false;
  String? _failedLocal;

  void _visibilityChanged(ThumbnailPriority? priority) {
    final wasVisible = _priority == ThumbnailPriority.visible;
    _priority = priority;
    if (priority == null ||
        (_original && priority != ThumbnailPriority.visible)) {
      _stop();
      return;
    }
    if (_request != null) {
      _request!.updatePriority(priority);
    } else if (_file == null) {
      if (!wasVisible && priority == ThumbnailPriority.visible) {
        _attempt = 0;
        _failed = false;
      }
      _start();
    }
  }

  void _stop() {
    _generation++;
    _request?.release();
    _request = null;
    _checkingCache = false;
    _retry?.cancel();
    _retry = null;
  }

  void _start() async {
    final loader = _loader;
    final priority = _priority;
    if (!mounted ||
        loader == null ||
        priority == null ||
        _request != null ||
        _checkingCache ||
        _retry != null ||
        _file != null ||
        _attempt >= 3 ||
        !loader.hasSources(widget.file) ||
        (_original && priority != ThumbnailPriority.visible))
      return;
    final generation = ++_generation;
    final original = _original;
    final file = widget.file;
    _checkingCache = true;
    File? cached;
    try {
      cached = await loader.cached(file);
    } catch (_) {
      /* Network may still work. */
    }
    if (!mounted || generation != _generation) return;
    _checkingCache = false;
    if (cached != null) {
      setState(() => _file = cached);
      return;
    }
    final currentPriority = _priority;
    if (currentPriority == null ||
        (original && currentPriority != ThumbnailPriority.visible))
      return;
    final request = ref
        .read(thumbnailSchedulerProvider)
        .request(
          '${identityHashCode(loader)}:$_key:$original',
          priority: currentPriority,
          original: original,
          load: (token) => loader.load(file, token, original: original),
        );
    _request = request;
    setState(() => _failed = false);
    unawaited(
      request.future.then((result) {
        if (!mounted || generation != _generation) return;
        _request = null;
        final cancelled = request.isCancelled;
        request.release();
        if (cancelled) {
          // A prefetch may enter the viewport while cancellation is settling.
          // Re-admit it immediately; cancellation is not a failed download.
          if (_priority == ThumbnailPriority.visible) _start();
          return;
        }
        if (result != null) {
          setState(() => _file = result);
          return;
        }
        if (!original && loader.canUseOriginal(file)) {
          _original = true;
          _start();
          return;
        }
        _attempt++;
        if (_priority == ThumbnailPriority.visible && _attempt < 3) {
          _retry = Timer(Duration(seconds: _attempt == 1 ? 2 : 6), () {
            _retry = null;
            _original = false;
            _start();
          });
        }
        setState(() => _failed = true);
      }),
    );
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = MediaSourceResolver.imageUrls(
      widget.file,
      MediaImageUse.thumbnail,
    );
    final variants = MediaSourceResolver.imageTelegramVariants(
      widget.file,
      MediaImageUse.thumbnail,
    );
    if (urls.isEmpty && variants.isEmpty) {
      _stop();
      return _frame(context, _fallback(context));
    }
    // Upload previews and fixture images are already on-device. Keep their
    // synchronous ImageCache fast path; no network admission or copy is needed.
    if (urls.isNotEmpty &&
        MediaSourceResolver.isLocalPath(urls.first) &&
        _failedLocal != urls.first) {
      _stop();
      final path = urls.first;
      return _frame(
        context,
        Image.file(
          File(path),
          fit: widget.fit,
          cacheWidth: widget.decodeWidth,
          errorBuilder: (_, __, ___) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _failedLocal != path)
                setState(() => _failedLocal = path);
            });
            return _fallback(context);
          },
        ),
      );
    }
    final loader = ref.watch(thumbnailLoaderProvider);
    final key = loader.keyFor(widget.file);
    if (!identical(loader, _loader) || _key != key) {
      _stop();
      _loader = loader;
      _key = key;
      _file = null;
      _attempt = 0;
      _failed = false;
      _original = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
    }
    final local = _file;
    final hasSources = loader.hasSources(widget.file);
    final child = local != null
        ? Image.file(
            local,
            fit: widget.fit,
            cacheWidth: widget.decodeWidth,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              final generation = _generation;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!mounted || generation != _generation || _file != local)
                  return;
                _stop();
                await loader.evict(widget.file);
                if (!mounted || !identical(loader, _loader)) return;
                setState(() {
                  _file = null;
                  _failed = true;
                });
                _attempt++;
                _start();
              });
              return _fallback(context);
            },
          )
        : _failed
        ? Semantics(
            label: 'Preview unavailable for ${widget.file.name}',
            child: _retryPlaceholder(context),
          )
        : hasSources
        ? Center(
            child: Semantics(
              label: 'Loading preview for ${widget.file.name}',
              child: MediaQuery.disableAnimationsOf(context)
                  ? const Icon(Icons.image_outlined)
                  : const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          )
        : _fallback(context);
    return ThumbnailVisibility(
      onChanged: _visibilityChanged,
      child: _frame(context, child),
    );
  }

  Widget _frame(BuildContext context, Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.radius),
    child: widget.showBackground
        ? ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: child,
          )
        : child,
  );

  Widget _retryPlaceholder(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final target = Theme.of(context).platform == TargetPlatform.iOS
          ? 44.0
          : 48.0;
      if (constraints.maxWidth < target || constraints.maxHeight < target) {
        return const Center(child: Icon(Icons.cloud_off_outlined, size: 20));
      }
      return Center(
        child: IconButton(
          tooltip: 'Retry preview for ${widget.file.name}',
          constraints: BoxConstraints(minWidth: target, minHeight: target),
          onPressed: () {
            _stop();
            _attempt = 0;
            _original = false;
            _start();
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    },
  );

  Widget _fallback(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minDim = math.min(constraints.maxWidth, constraints.maxHeight);
      final iconSize = (minDim.isInfinite || minDim <= 0) ? 40.0 : minDim;
      return Center(
        child: Padding(
          padding: EdgeInsets.all(iconSize * 0.08),
          child: Theme.of(context).platform == TargetPlatform.iOS
              ? Icon(
                  switch (widget.file.kind) {
                    FileKind.image => CupertinoIcons.photo,
                    FileKind.video => CupertinoIcons.videocam,
                    FileKind.audio => CupertinoIcons.music_note,
                    FileKind.folder => CupertinoIcons.folder,
                    FileKind.sheet => CupertinoIcons.table,
                    _ => CupertinoIcons.doc,
                  },
                  size: math.min(iconSize * 0.84, 48.0),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )
              : GoogleDriveIcon.file(
                  widget.file,
                  size: math.min(iconSize * 0.84, 48.0),
                ),
        ),
      );
    },
  );
}
