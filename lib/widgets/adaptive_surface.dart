import 'dart:ui';
import 'package:flutter/material.dart';

/// Floating controls use frosted material on iOS; content stays opaque.
/// Flutter approximation of glass, not a native Liquid Glass implementation.
class AdaptiveSurface extends StatelessWidget {
  const AdaptiveSurface({required this.child, this.radius = 28, super.key});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass =
        theme.platform == TargetPlatform.iOS &&
        !MediaQuery.highContrastOf(context) &&
        !MediaQuery.accessibleNavigationOf(context) &&
        !MediaQuery.disableAnimationsOf(context);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: glass ? .84 : 1),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: MediaQuery.highContrastOf(context)
              ? scheme.outline
              : scheme.outlineVariant.withValues(alpha: .45),
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .07),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: glass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: content,
              )
            : content,
      ),
    );
  }
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
