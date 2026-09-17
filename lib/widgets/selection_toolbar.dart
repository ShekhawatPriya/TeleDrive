import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'native_glass_button.dart';

/// Shared selection controls that wrap instead of squeezing the title on phones.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.count,
    required this.onCancel,
    required this.actions,
    this.actionsOnly = false,
    super.key,
  });
  final bool actionsOnly;
  final int count;
  final VoidCallback onCancel;
  final List<({String label, IconData icon, VoidCallback onPressed})> actions;
  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      if (actionsOnly) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final action in actions)
                  NativeGlassButton(
                    label: action.label,
                    symbol: switch (action.label) {
                      'Share' => 'square.and.arrow.up',
                      'Star' => 'star',
                      'Move' => 'folder',
                      'Delete' => 'trash',
                      _ => 'ellipsis',
                    },
                    icon: switch (action.label) {
                      'Share' => CupertinoIcons.share,
                      'Star' => CupertinoIcons.star,
                      'Move' => CupertinoIcons.folder,
                      'Delete' => CupertinoIcons.trash,
                      _ => CupertinoIcons.ellipsis,
                    },
                    onPressed: count > 0 ? action.onPressed : null,
                  ),
              ],
            ),
          ),
        );
      }
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  header: true,
                  child: Text(
                    count > 0 ? '$count selected' : 'Select items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(48, 48),
                onPressed: onCancel,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }
    if (actionsOnly) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        count > 0 ? '$count selected' : 'Select items',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  TextButton(onPressed: onCancel, child: const Text('Done')),
                ],
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final action in actions)
                    TextButton.icon(
                      onPressed: count > 0 ? action.onPressed : null,
                      icon: Icon(action.icon, size: 20),
                      label: Text(action.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
