import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/search_keyboard.dart';

extension SafeNavigationContext on BuildContext {
  static DateTime _lastNavigated = DateTime.fromMillisecondsSinceEpoch(0);
  static GoRouter? _lastRouter;
  static String? _lastLocation;
  static const Duration _cooldown = Duration(milliseconds: 500);

  /// Pushes a location onto the navigation stack safely, preventing rapid duplicate push operations.
  void safePush(String location, {Object? extra}) {
    final now = DateTime.now();
    final router = GoRouter.of(this);
    if (identical(router, _lastRouter) &&
        location == _lastLocation &&
        now.difference(_lastNavigated) < _cooldown) {
      return;
    }
    _lastNavigated = now;
    _lastRouter = router;
    _lastLocation = location;
    dismissSearchKeyboard();
    push(location, extra: extra);
  }
}
