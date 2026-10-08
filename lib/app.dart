import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/app_update/app_update_gate.dart';
import 'features/auth/profile_refresh_gate.dart';
import 'features/profile/theme_controller.dart';
import 'widgets/ios/ios_accessibility.dart';

class TeleDriveApp extends ConsumerWidget {
  const TeleDriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TeleDrive',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppBrand.scheme(Brightness.light)),
      darkTheme: buildTheme(AppBrand.scheme(Brightness.dark)),
      highContrastTheme: buildTheme(
        AppBrand.scheme(Brightness.light, highContrast: true),
        highContrast: true,
      ),
      highContrastDarkTheme: buildTheme(
        AppBrand.scheme(Brightness.dark, highContrast: true),
        highContrast: true,
      ),
      themeMode: theme.mode,
      routerConfig: router,
      builder: (context, child) {
        return IosAccessibility(
          child: ProfileRefreshGate(
            child: AppUpdateGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
