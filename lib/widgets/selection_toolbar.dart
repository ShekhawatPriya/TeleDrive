import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'native_glass_button.dart';
import 'native_selection_actions.dart';

/// Shared selection controls that wrap instead of squeezing the title on phones.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    required this.count,
    required this.onCancel,
    required this.actions,
    this.actionsOnly = false,
    this.onSelectAll,
    this.onClear,
    super.key,
  });
  final bool actionsOnly;
  final VoidCallback? onSelectAll, onClear;
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
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: NativeSelectionActions(
              actions: actions,
              enabled: count > 0,
              onSelectAll: onSelectAll,
              onClear: onClear,
            ),
          ),
        );
      }
      final largeText = MediaQuery.textScalerOf(context).scale(17) > 24;
      final stacked = largeText || MediaQuery.sizeOf(context).width < 360;
      final title = Semantics(
        liveRegion: true,
        header: true,
        child: Text(
          count == 1 ? '1 Item' : '$count Items',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      final selectAll = onSelectAll == null
          ? const SizedBox(width: 48)
          : NativeGlassButton(
              label: 'Select All',
              symbol: '',
              icon: CupertinoIcons.check_mark_circled,
              size: largeText ? 56 : 44,
              width: largeText ? 180 : 104,
              onPressed: onSelectAll,
            );
      final done = NativeGlassButton(
        label: 'Done',
        symbol: 'checkmark',
        icon: CupertinoIcons.check_mark,
        size: 44,
        symbolSize: 24,
        prominent: true,
        onPressed: onCancel,
      );
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (stacked)
                Row(children: [selectAll, const Spacer(), done])
              else
                SizedBox(
                  height: 44,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 108),
                        child: title,
                      ),
                      Align(alignment: Alignment.centerLeft, child: selectAll),
                      Align(alignment: Alignment.centerRight, child: done),
                    ],
                  ),
                ),
              if (stacked)
                Padding(padding: const EdgeInsets.only(top: 4), child: title),
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
