import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/ios_palette.dart';
import 'launch_mark.dart';

/// Continues the native launch screen; the router owns startup readiness.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Native launch follows system appearance. Keep that appearance throughout
    // startup, even if a saved in-app theme loads while authentication is pending.
    final brightness = MediaQuery.platformBrightnessOf(context);
    final base = AppBrand.scheme(brightness);
    final scheme = Theme.of(context).platform == TargetPlatform.iOS
        ? iosPalette(base)
        : base;
    final dark = brightness == Brightness.dark;
    final background = scheme.surface;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: background,
            systemNavigationBarDividerColor: background,
          ),
      child: Scaffold(
        backgroundColor: background,
        body: Semantics(
          label: 'TeleDrive. Opening your drive',
          liveRegion: true,
          child: Center(child: LaunchMark(color: scheme.onSurface)),
        ),
      ),
    );
  }
}
