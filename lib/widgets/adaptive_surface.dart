import 'dart:ui';
import 'package:flutter/material.dart';

enum GlassRole { sheet, navigation }

/// Floating controls use frosted material on iOS; content stays opaque.
/// Flutter approximation of glass, not a native Liquid Glass implementation.
class AdaptiveSurface extends StatelessWidget {
  const AdaptiveSurface({
    required this.child,
    this.radius = 28,
    this.role = GlassRole.sheet,
    super.key,
  });
  final Widget child;
  final double radius;
  final GlassRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Sheets carry reading content and actions. An opaque surface prevents
    // underlying labels bleeding through and needs no decorative glass rim.
    if (theme.platform == TargetPlatform.iOS && role == GlassRole.sheet) {
      return ClipRSuperellipse(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(color: scheme.surfaceContainerLow, child: child),
      );
    }
    final navigation =
        theme.platform == TargetPlatform.iOS && role == GlassRole.navigation;
    final dark = theme.brightness == Brightness.dark;
    final glass =
        theme.platform == TargetPlatform.iOS &&
        !MediaQuery.highContrastOf(context);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : scheme.surfaceContainerLow,
        gradient: glass
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerLow.withValues(
                    alpha: navigation ? (dark ? .32 : .30) : .88,
                  ),
                  scheme.surfaceContainerLow.withValues(
                    alpha: navigation ? (dark ? .20 : .16) : .78,
                  ),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: glass
            ? null
            : Border.all(
                color: MediaQuery.highContrastOf(context)
                    ? scheme.outline
                    : glass
                    ? Colors.white.withValues(
                        alpha: dark ? .22 : (navigation ? .65 : .7),
                      )
                    : scheme.outlineVariant.withValues(alpha: .45),
              ),
      ),
      child: child,
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: glass
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: navigation ? 14 : 24,
                sigmaY: navigation ? 14 : 24,
              ),
              child: content,
            )
          : content,
    );
    if (glass) {
      // A normal filled BoxShadow is visible THROUGH a translucent child.
      // Keep the shadow outside the glass so it cannot muddy the backdrop.
      return CustomPaint(
        painter: _GlassShadow(
          radius: radius,
          navigation: navigation,
          color: scheme.shadow.withValues(alpha: navigation ? .13 : .10),
        ),
        child: clipped,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: navigation ? .13 : .07),
            blurRadius: navigation ? 18 : 28,
            offset: Offset(0, navigation ? 5 : 8),
          ),
        ],
      ),
      child: clipped,
    );
  }
}

class _GlassShadow extends CustomPainter {
  const _GlassShadow({
    required this.radius,
    required this.navigation,
    required this.color,
  });
  final double radius;
  final bool navigation;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(50))
      ..addRRect(shape);
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawRRect(
      shape.shift(Offset(0, navigation ? 5 : 8)),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, navigation ? 10 : 16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassShadow old) =>
      radius != old.radius ||
      navigation != old.navigation ||
      color != old.color;
}

/// A compact, editorial introduction to a collection, with truthful context.
class CollectionIntro extends StatelessWidget {
  const CollectionIntro({
    required this.title,
    required this.description,
    required this.icon,
    this.detail,
    super.key,
  });
  final String title;
  final String description;
  final String? detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ios = theme.platform == TargetPlatform.iOS;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: ios ? scheme.surfaceContainerLow : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(ios ? 26 : 30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 26,
                color: ios ? scheme.primary : scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              if (detail != null)
                Expanded(
                  child: Text(
                    detail!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ios
                          ? scheme.onSurfaceVariant
                          : scheme.onSecondaryContainer,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: ios ? scheme.onSurface : scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ios
                  ? scheme.onSurfaceVariant
                  : scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
