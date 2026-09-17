import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// A highly-polished, animated selection indicator.
///
/// It displays a premium circular checkbox that:
/// - In lists: stays clean, using a thin outline when unselected and a vibrant filled check when selected.
/// - Over images/grids: uses a frosted, semi-transparent backdrop when unselected to ensure visibility.
/// - Features a smooth scale and spring-like checkmark bounce animation when selected.
class PremiumSelectionIndicator extends StatelessWidget {
  const PremiumSelectionIndicator({
    required this.isSelected,
    this.isOverImage = false,
    this.size = 22.0,
    super.key,
  });

  /// Whether the item is selected.
  final bool isSelected;

  /// Whether the indicator is rendered on top of an image or thumbnail.
  /// If true, applies high-contrast styling with a subtle shadow and dark translucent fill.
  final bool isOverImage;

  /// The size of the indicator bounding box.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Harmonized colors for the premium look & feel
    final ios = theme.platform == TargetPlatform.iOS;
    final activeColor = ios
        ? CupertinoColors.activeBlue.resolveFrom(context)
        : scheme.primary;
    final inactiveBorderColor = isOverImage
        ? Colors.white.withValues(alpha: 0.9)
        : scheme.onSurfaceVariant.withValues(alpha: 0.38);
    final inactiveBgColor = isOverImage
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.transparent;

    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isSelected ? activeColor : inactiveBgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? activeColor : inactiveBorderColor,
          width: 1.5,
        ),
        boxShadow: isSelected && isOverImage
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: isSelected ? 1.0 : 0.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        child: Center(
          child: Icon(
            ios ? CupertinoIcons.check_mark : Icons.check,
            size: size * 0.65,
            color: ios ? Colors.white : scheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
