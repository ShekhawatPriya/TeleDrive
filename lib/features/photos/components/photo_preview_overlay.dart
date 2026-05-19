import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_type_detector.dart';
import '../../../models/drive_models.dart';
import '../../../widgets/media_thumb.dart';

/// iOS-style contextual preview: scales the pressed tile up to a centered
/// preview, blurs and dims the rest of the screen, and floats a menu card
/// below.  Built as a [PopupRoute] so that tapping the barrier dismisses the
/// overlay with the reverse animation, matching the system look.
Future<void> showPhotoPreviewOverlay({
  required BuildContext context,
  required Rect sourceRect,
  required DriveFile file,
  required VoidCallback onShare,
  required VoidCallback onMove,
  required VoidCallback onSelect,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    _PhotoPreviewRoute(
      sourceRect: sourceRect,
      file: file,
      onShare: onShare,
      onMove: onMove,
      onSelect: onSelect,
    ),
  );
}

class _PhotoPreviewRoute extends PopupRoute<void> {
  _PhotoPreviewRoute({
    required this.sourceRect,
    required this.file,
    required this.onShare,
    required this.onMove,
    required this.onSelect,
  });

  final Rect sourceRect;
  final DriveFile file;
  final VoidCallback onShare;
  final VoidCallback onMove;
  final VoidCallback onSelect;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss preview';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 240);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _PhotoPreviewBody(
      sourceRect: sourceRect,
      file: file,
      animation: animation,
      onShare: onShare,
      onMove: onMove,
      onSelect: onSelect,
    );
  }
}

class _PhotoPreviewBody extends StatelessWidget {
  const _PhotoPreviewBody({
    required this.sourceRect,
    required this.file,
    required this.animation,
    required this.onShare,
    required this.onMove,
    required this.onSelect,
  });

  final Rect sourceRect;
  final DriveFile file;
  final Animation<double> animation;
  final VoidCallback onShare;
  final VoidCallback onMove;
  final VoidCallback onSelect;

  static const double _menuWidth = 260;
  static const double _menuHeight = 169;
  static const double _gap = 14;
  static const double _edgeMargin = 16;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final targetRect = _computeTargetRect(size, padding);

    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final rectTween = RectTween(begin: sourceRect, end: targetRect);

    return AnimatedBuilder(
      animation: eased,
      builder: (context, _) {
        final t = eased.value;
        final rect = rectTween.transform(t)!;
        final menuLeft = (rect.center.dx - _menuWidth / 2).clamp(
          _edgeMargin,
          size.width - _menuWidth - _edgeMargin,
        );
        final menuTop = rect.bottom + _gap;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    Navigator.of(context, rootNavigator: true).maybePop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .28 * t),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: IgnorePointer(
                child: _PreviewCard(file: file, progress: t),
              ),
            ),
            Positioned(
              left: menuLeft,
              top: menuTop,
              width: _menuWidth,
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 12),
                  child: _PreviewMenuCard(
                    onShare: () => _dismiss(context, onShare),
                    onMove: () => _dismiss(context, onMove),
                    onSelect: () => _dismiss(context, onSelect),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _dismiss(BuildContext context, VoidCallback after) {
    Navigator.of(context, rootNavigator: true).pop();
    after();
  }

  Rect _computeTargetRect(Size size, EdgeInsets padding) {
    final availableWidth = size.width - _edgeMargin * 2;
    final availableHeight =
        size.height -
        padding.top -
        padding.bottom -
        _menuHeight -
        _gap -
        _edgeMargin * 2;
    final maxWidth = availableWidth.clamp(0.0, 420.0);
    final maxHeight = availableHeight.clamp(0.0, size.height * 0.62);

    final aspect = sourceRect.width <= 0 || sourceRect.height <= 0
        ? 1.0
        : sourceRect.width / sourceRect.height;

    double w = maxWidth;
    double h = w / aspect;
    if (h > maxHeight) {
      h = maxHeight;
      w = h * aspect;
    }
    if (w > maxWidth) {
      w = maxWidth;
      h = w / aspect;
    }

    final blockHeight = h + _gap + _menuHeight;
    final topInset = padding.top + _edgeMargin;
    final bottomInset = padding.bottom + _edgeMargin;
    final freeSpace = size.height - topInset - bottomInset - blockHeight;
    final top = topInset + (freeSpace > 0 ? freeSpace * 0.42 : 0);
    final left = (size.width - w) / 2;
    return Rect.fromLTWH(left, top, w, h);
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.file, required this.progress});

  final DriveFile file;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final radius = 6 + (16 - 6) * progress;
    final shadowOpacity = 0.18 * progress;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 28 * progress,
            offset: Offset(0, 12 * progress),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MediaThumb(file: file, fit: BoxFit.cover, radius: 0),
            if (isVideoFile(file)) _videoBadge(),
          ],
        ),
      ),
    );
  }

  Widget _videoBadge() {
    final hasDuration = file.duration != null;
    return Positioned(
      left: 10,
      bottom: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: hasDuration ? 9 : 6,
            vertical: 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 16,
              ),
              if (hasDuration) ...[
                const SizedBox(width: 3),
                Text(
                  formatDuration(file.duration!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMenuCard extends StatelessWidget {
  const _PreviewMenuCard({
    required this.onShare,
    required this.onMove,
    required this.onSelect,
  });

  final VoidCallback onShare;
  final VoidCallback onMove;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = scheme.surface.withValues(alpha: .96);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: cardColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuRow(label: 'Share', icon: Icons.ios_share, onTap: onShare),
              _hairline(scheme),
              _MenuRow(
                label: 'Move',
                icon: Icons.drive_file_move_outline,
                onTap: onMove,
              ),
              _hairline(scheme),
              _MenuRow(
                label: 'Select',
                icon: Icons.check_circle_outline,
                onTap: onSelect,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hairline(ColorScheme scheme) =>
      Container(height: 0.5, color: scheme.outline);
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(icon, size: 22, color: color),
          ],
        ),
      ),
    );
  }
}
