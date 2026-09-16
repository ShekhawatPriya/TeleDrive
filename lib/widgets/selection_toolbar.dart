import 'package:flutter/material.dart';

/// Shared selection controls that wrap instead of squeezing the title on phones.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.count,
    required this.onCancel,
    required this.actions,
    super.key,
  });
  final int count;
  final VoidCallback onCancel;
  final List<({String label, IconData icon, VoidCallback onPressed})> actions;
  @override
  Widget build(BuildContext context) => Material(
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
