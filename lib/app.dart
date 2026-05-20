import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/theme_controller.dart';

class TeleDriveApp extends ConsumerWidget {
  const TeleDriveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final router = ref.watch(routerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightFallback = ColorScheme.fromSeed(
          seedColor: AppBrand.seed,
          brightness: Brightness.light,
        );
        final darkFallback = ColorScheme.fromSeed(
          seedColor: AppBrand.seed,
          brightness: Brightness.dark,
        );
        final lightScheme = (lightDynamic ?? lightFallback).harmonized();
        final darkScheme = (darkDynamic ?? darkFallback).harmonized();
        return MaterialApp.router(
          title: 'TeleDrive',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(lightScheme),
          darkTheme: buildTheme(darkScheme),
          themeMode: theme.mode,
          routerConfig: router,
        );
      },
    );
  }
}
