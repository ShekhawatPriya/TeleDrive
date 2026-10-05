import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'adaptive_surface.dart';
import 'ios_more_menu.dart';

typedef SelectionAction = ({
  String label,
  IconData icon,
  VoidCallback onPressed,
});

/// UIKit groups the primary actions into one glass toolbar, with a separate
/// overflow group. Flutter retains the callbacks and disabled-selection state.
class NativeSelectionActions extends StatefulWidget {
  const NativeSelectionActions({
    required this.actions,
    required this.enabled,
    this.onSelectAll,
    this.onClear,
    super.key,
  });
  final List<SelectionAction> actions;
  final bool enabled;
  final VoidCallback? onSelectAll, onClear;
  @override
  State<NativeSelectionActions> createState() => _NativeSelectionActionsState();
}

class _NativeSelectionActionsState extends State<NativeSelectionActions> {
  MethodChannel? _channel;
  bool _available = false, _checked = false;
  List<String>? _lastLabels;
  (bool, bool, bool, bool)? _lastState;
  static String symbol(String label) => switch (label) {
    'Share' => 'square.and.arrow.up',
    'Star' => 'star',
    'Move' => 'folder',
    'Delete' => 'trash',
    _ => 'ellipsis',
  };
  static IconData icon(String label) => switch (label) {
    'Share' => CupertinoIcons.share,
    'Star' => CupertinoIcons.star,
    'Move' => CupertinoIcons.folder,
    'Delete' => CupertinoIcons.trash,
    _ => CupertinoIcons.ellipsis,
  };
  Map<String, Object> get configuration => {
    'dark': Theme.of(context).brightness == Brightness.dark,
    'enabled': widget.enabled,
    'selectAll': widget.onSelectAll != null,
    'clear': widget.onClear != null && widget.enabled,
    'actions': [
      for (final a in widget.actions)
        {'label': a.label, 'symbol': symbol(a.label)},
    ],
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checked) {
      _checked = true;
      _check();
    }
    _update();
  }

  Future<void> _check() async {
    try {
      final available =
          await const MethodChannel(
            'teledrive/appearance',
          ).invokeMethod<bool>('supportsSelectionToolbar') ??
          false;
      if (mounted) setState(() => _available = available);
    } on PlatformException {
      /* Flutter fallback. */
    } on MissingPluginException {
      /* Flutter fallback. */
    }
  }

  @override
  void didUpdateWidget(NativeSelectionActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  void _update() {
    if (_channel == null) return;
    final labels = widget.actions.map((a) => a.label).toList();
    final state = (
      Theme.of(context).brightness == Brightness.dark,
      widget.enabled,
      widget.onSelectAll != null,
      widget.onClear != null && widget.enabled,
    );
    if (state == _lastState && listEquals(labels, _lastLabels)) return;
    _lastState = state;
    _lastLabels = labels;
    _channel
        ?.invokeMethod<void>('update', configuration)
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: _available
        ? UiKitView(
            viewType: 'teledrive/selection-toolbar',
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: configuration,
            onPlatformViewCreated: (id) {
              _lastState = null;
              _lastLabels = null;
              _channel = MethodChannel('teledrive/selection-toolbar/$id');
              _channel!.setMethodCallHandler((call) async {
                if (!mounted || call.method != 'action') return;
                if (call.arguments == 'Select All') {
                  widget.onSelectAll?.call();
                  return;
                }
                if (!widget.enabled) return;
                if (call.arguments == 'Deselect All') {
                  widget.onClear?.call();
                  return;
                }
                for (final action in widget.actions) {
                  if (action.label == call.arguments) {
                    action.onPressed();
                    return;
                  }
                }
              });
              _update();
            },
          )
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                AdaptiveSurface(
                  role: GlassRole.navigation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in widget.actions)
                          Tooltip(
                            message: action.label,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(48, 48),
                              onPressed: widget.enabled
                                  ? action.onPressed
                                  : null,
                              child: Icon(
                                icon(action.label),
                                size: 24,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: widget.enabled ? 1 : .3),
                                semanticLabel: action.label,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onSelectAll != null || widget.onClear != null)
                  IosMoreButton(
                    tooltip: 'Selection options',
                    sectionsBuilder: (_) => [
                      IosMenuSection([
                        if (widget.onSelectAll != null)
                          IosMenuItem(
                            label: 'Select All',
                            leadingIcon: CupertinoIcons.check_mark_circled,
                            onTap: widget.onSelectAll!,
                          ),
                        if (widget.onClear != null && widget.enabled)
                          IosMenuItem(
                            label: 'Deselect All',
                            leadingIcon: CupertinoIcons.circle,
                            onTap: widget.onClear!,
                          ),
                      ]),
                    ],
                  ),
              ],
            ),
          ),
  );
}
