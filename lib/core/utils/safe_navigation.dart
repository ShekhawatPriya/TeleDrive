import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension SafeNavigationContext on BuildContext {
  static DateTime _lastNavigated = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  /// Pushes a location onto the navigation stack safely, preventing rapid duplicate push operations.
  void safePush(String location, {Object? extra}) {
    final now = DateTime.now();
    if (now.difference(_lastNavigated) < _cooldown) {
      return;
    }
    _lastNavigated = now;
    push(location, extra: extra);
  }
}
