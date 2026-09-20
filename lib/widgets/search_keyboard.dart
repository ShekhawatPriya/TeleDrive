import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Resign both Flutter and UIKit responders before changing destinations.
void dismissSearchKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  unawaited(
    const MethodChannel(
      'teledrive/appearance',
    ).invokeMethod<void>('dismissKeyboard').catchError((Object _) {}),
  );
}

class SearchKeyboardObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      dismissSearchKeyboard();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      dismissSearchKeyboard();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      dismissSearchKeyboard();
}
