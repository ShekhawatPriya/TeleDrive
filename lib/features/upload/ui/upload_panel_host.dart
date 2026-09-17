import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'upload_sheet.dart';

/// Keeps the iOS transfer surface in the content layer, underneath the shell's
/// native tab bar. The body must extend behind navigation, as MainShell does.
class UploadPanelHost extends StatefulWidget {
  const UploadPanelHost({required this.child, super.key});
  final Widget child;

  @override
  State<UploadPanelHost> createState() => _UploadPanelHostState();
}

class _UploadPanelHostState extends State<UploadPanelHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(vsync: this);
  }

  Completer<void>? _completion;
  LocalHistoryEntry? _history;
  bool _disposing = false;

  Future<void> open() {
    if (_completion != null) return _completion!.future;
    FocusManager.instance.primaryFocus?.unfocus();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _animation.duration = reducedMotion ? Duration.zero : AppDurations.medium2;
    _animation.reverseDuration = reducedMotion
        ? Duration.zero
        : AppDurations.short4;
    final completion = _completion = Completer<void>();
    _history = LocalHistoryEntry(onRemove: _hide);
    ModalRoute.of(context)?.addLocalHistoryEntry(_history!);
    setState(() {});
    _animation.forward(from: 0);
    return completion.future;
  }

  void _close() => _history?.remove();

  Future<void> _hide() async {
    _history = null;
    if (_disposing) return;
    try {
      await _animation.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    final completion = _completion;
    setState(() => _completion = null);
    completion?.complete();
  }

  @override
  void dispose() {
    // Removing route history during teardown must not animate a dead host.
    _disposing = true;
    _history?.remove();
    _animation.dispose();
    _completion?.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return _UploadPanelScope(
      host: this,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_completion != null)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SlideTransition(
                    position: _animation.drive(
                      Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic)),
                    ),
                    child:
                        NotificationListener<DraggableScrollableNotification>(
                          onNotification: (notification) {
                            if (notification.extent <= notification.minExtent &&
                                notification.shouldCloseOnMinExtent)
                              _close();
                            return true;
                          },
                          child: UploadSheet(
                            onMinimize: _close,
                            bottomInset: bottomInset,
                          ),
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadPanelScope extends InheritedWidget {
  const _UploadPanelScope({required this.host, required super.child});
  final _UploadPanelHostState host;

  @override
  bool updateShouldNotify(_UploadPanelScope oldWidget) =>
      host != oldWidget.host;
}

/// Use the shell's extended iOS content layer when available. Android and
/// standalone pages retain the scaffold sheet and its navigation clearance.
Future<void> showUploadPanel(BuildContext context) {
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    final scope = context.getInheritedWidgetOfExactType<_UploadPanelScope>();
    if (scope != null) return scope.host.open();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  final scaffold = Scaffold.of(context);
  final bottomInset = scaffold.widget.bottomNavigationBar == null
      ? MediaQuery.viewPaddingOf(scaffold.context).bottom
      : 0.0;
  late PersistentBottomSheetController panel;
  panel = scaffold.showBottomSheet(
    (context) =>
        UploadSheet(onMinimize: () => panel.close(), bottomInset: bottomInset),
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(),
    clipBehavior: Clip.none,
    enableDrag: false,
    showDragHandle: false,
    constraints: const BoxConstraints(maxWidth: 600),
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
  );
  return panel.closed;
}
