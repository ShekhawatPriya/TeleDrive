import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'premium_toast.dart';
import '../core/utils/app_haptics.dart';

/// Brief, non-blocking feedback. iOS has no snackbar, so iOS uses the app's
/// rounded toast; Android keeps the Material snackbar.
///
/// Capture with [AppMessenger.of] before an `await` when the calling widget
/// may unmount, as with `ScaffoldMessenger.of`.
class AppMessenger {
  AppMessenger._(this._ios, this._messenger);

  factory AppMessenger.of(BuildContext context) => AppMessenger._(
    Theme.of(context).platform == TargetPlatform.iOS,
    ScaffoldMessenger.maybeOf(context),
  );

  final bool _ios;
  final ScaffoldMessengerState? _messenger;

  void show(
    String message, {
    bool error = false,
    IconData? iosIcon,
    Duration? duration,
    SnackBarBehavior? behavior,
    Color? backgroundColor,
  }) {
    if (_ios) {
      if (error) AppHaptics.error();
      showAppPremiumToast(
        message: message,
        icon:
            iosIcon ??
            (error
                ? CupertinoIcons.exclamationmark_circle
                : CupertinoIcons.checkmark_circle),
        duration: duration ?? const Duration(milliseconds: 3500),
      );
      return;
    }
    _messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(milliseconds: 4000),
        behavior: behavior,
        backgroundColor: backgroundColor,
      ),
    );
  }
}

void showAppMessage(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? iosIcon,
  Duration? duration,
}) => AppMessenger.of(
  context,
).show(message, error: error, iosIcon: iosIcon, duration: duration);
