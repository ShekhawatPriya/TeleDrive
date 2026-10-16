import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS feedback for common actions, matching the system apps: a tick when
/// toggling selection, a light tap for star/copy, a success tap when work
/// finishes and a warning before destructive confirmation. iOS applies the
/// user's System Haptics setting. Android keeps its existing behavior.
abstract final class AppHaptics {
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static void selection() {
    if (_ios) HapticFeedback.selectionClick();
  }

  static void light() {
    if (_ios) HapticFeedback.lightImpact();
  }

  static void success() {
    if (_ios) HapticFeedback.successNotification();
  }

  static void warning() {
    if (_ios) HapticFeedback.warningNotification();
  }

  static void error() {
    if (_ios) HapticFeedback.errorNotification();
  }
}
