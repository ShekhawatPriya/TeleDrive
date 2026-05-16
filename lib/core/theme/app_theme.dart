import 'package:flutter/material.dart';

class AppColors {
  static const parchment = Color(0xfff5f4ed);
  static const ivory = Color(0xfffaf9f5);
  static const nearBlack = Color(0xff141413);
  static const terracotta = Color(0xffc96442);
  static const coral = Color(0xffd97757);
  static const warmSand = Color(0xffe8e6dc);
  static const border = Color(0xfff0eee6);
  static const oliveGray = Color(0xff5e5d59);
  static const stone = Color(0xff87867f);
  static const darkSurface = Color(0xff30302e);
  static const error = Color(0xffb53333);
  static const success = Color(0xff5c6e4a);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: dark ? AppColors.coral : AppColors.terracotta,
    brightness: brightness,
    primary: dark ? AppColors.coral : AppColors.terracotta,
    surface: dark ? AppColors.darkSurface : AppColors.ivory,
    error: AppColors.error,
  );
  final bg = dark ? AppColors.nearBlack : AppColors.parchment;
  final text = dark ? AppColors.ivory : AppColors.nearBlack;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: scheme.copyWith(
      surface: dark ? AppColors.darkSurface : AppColors.ivory,
      onSurface: text,
      secondary: dark ? const Color(0xff3d3d3a) : AppColors.warmSand,
      outline: dark ? AppColors.darkSurface : AppColors.border,
    ),
    fontFamily: 'Roboto',
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 34,
        fontWeight: FontWeight.w500,
        color: text,
        height: 1.12,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Georgia',
        fontSize: 26,
        fontWeight: FontWeight.w500,
        color: text,
        height: 1.16,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: text),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: dark ? const Color(0xffb0aea5) : AppColors.oliveGray,
      ),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? AppColors.darkSurface : AppColors.ivory,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? const Color(0xff3d3d3a) : AppColors.border,
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff3d3d3a) : AppColors.ivory,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xff3898ec), width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? AppColors.coral : AppColors.terracotta,
        foregroundColor: AppColors.ivory,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        backgroundColor: dark ? const Color(0xff3d3d3a) : AppColors.warmSand,
        foregroundColor: dark
            ? const Color(0xffb0aea5)
            : const Color(0xff4d4c48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.nearBlack : AppColors.parchment,
      indicatorColor: (dark ? AppColors.coral : AppColors.terracotta)
          .withValues(alpha: .15),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
