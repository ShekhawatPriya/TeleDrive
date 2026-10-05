import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/ios_accessibility_controller.dart';

/// Place above the Navigator so routes, sheets and overlay banners share it.
class IosAccessibility extends StatefulWidget {
  const IosAccessibility({required this.child, super.key});
  final Widget child;

  @override
  State<IosAccessibility> createState() => _IosAccessibilityState();
}

class _IosAccessibilityState extends State<IosAccessibility>
    with WidgetsBindingObserver {
  IosAccessibilityController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null &&
        Theme.of(context).platform == TargetPlatform.iOS) {
      _controller = IosAccessibilityController();
      WidgetsBinding.instance.addObserver(this);
      unawaited(_controller!.start());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (controller != null) unawaited(controller.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? widget.child
      : ListenableBuilder(
          listenable: _controller!,
          builder: (context, _) => IosAccessibilityPreferences(
            reduceTransparency: _controller!.reduceTransparency,
            child: widget.child,
          ),
        );
}

class IosAccessibilityPreferences extends InheritedWidget {
  const IosAccessibilityPreferences({
    required this.reduceTransparency,
    required super.child,
    super.key,
  });
  final bool reduceTransparency;

  static bool reduceTransparencyOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<IosAccessibilityPreferences>()
          ?.reduceTransparency ??
      false;

  @override
  bool updateShouldNotify(IosAccessibilityPreferences oldWidget) =>
      reduceTransparency != oldWidget.reduceTransparency;
}
