import 'package:flutter/material.dart';

/// One status language for Android cards, rows and recent previews.
/// Markers occupy their own space; they never cover a folder or each other.
class ItemStatusIndicators extends StatelessWidget {
  const ItemStatusIndicators({
    super.key,
    required this.starred,
    required this.shared,
  });
  final bool starred;
  final bool shared;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!starred && !shared) return const SizedBox.shrink();
    return Semantics(
      label: [if (starred) 'Starred', if (shared) 'Shared'].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (starred)
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
              if (starred && shared) const SizedBox(width: 4),
              if (shared)
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
