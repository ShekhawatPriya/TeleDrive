import 'package:flutter/material.dart';

/// Shared saved-item marker, matching the drive home folder cards.
class StarredBadge extends StatelessWidget {
  const StarredBadge({super.key, this.size = 18, this.backgroundColor});

  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color:
          backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
    ),
    child: Icon(
      Icons.star_rounded,
      size: size * 14 / 18,
      color: const Color(0xFFFFC533),
      semanticLabel: 'Starred',
    ),
  );
}
