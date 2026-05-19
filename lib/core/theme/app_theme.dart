import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xff171717);
  static const canvas = Color(0xffffffff);
  static const canvasSoft = Color(0xfffafafa);
  static const canvasSoft2 = Color(0xfff5f5f5);
  static const hairline = Color(0xffebebeb);
  static const hairlineStrong = Color(0xffa1a1a1);
  static const body = Color(0xff4d4d4d);
  static const mute = Color(0xff888888);
  static const link = Color(0xff0070f3);
  static const linkDeep = Color(0xff0761d1);
  static const linkBgSoft = Color(0xffd3e5ff);
  static const error = Color(0xffee0000);
  static const errorSoft = Color(0xfff7d4d6);
  static const errorDeep = Color(0xffc50000);
  static const warning = Color(0xfff5a623);
  static const warningSoft = Color(0xffffefcf);
  static const success = Color(0xff0070f3);
  static const green = Color(0xff008a05);
  static const cyan = Color(0xff50e3c2);
  static const violet = Color(0xff7928ca);
  static const pink = Color(0xffff0080);
  static const amber = Color(0xfff9cb28);

  static const darkCanvas = Color(0xff000000);
  static const darkSurface = Color(0xff111111);
  static const darkSurface2 = Color(0xff1f1f1f);
  static const darkHairline = Color(0xff2e2e2e);
  static const darkHairlineStrong = Color(0xff5f5f5f);
  static const darkBody = Color(0xffd4d4d4);
  static const darkMute = Color(0xff8f8f8f);
  static const darkErrorSoft = Color(0xff3a1214);

  static Color page(Brightness brightness) =>
      brightness == Brightness.dark ? darkCanvas : canvasSoft;

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : canvas;

  static Color surfaceSubtle(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface2 : canvasSoft2;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkHairline : hairline;

  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? canvasSoft : ink;

  static Color textMuted(Brightness brightness) =>
      brightness == Brightness.dark ? darkMute : mute;
}

class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 40.0;
}

class AppRadii {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const sheet = 28.0;
  static const pill = 100.0;
}

class AppShadows {
  static List<BoxShadow> card(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 24,
          offset: Offset(0, 16),
          spreadRadius: -18,
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x0c000000),
        blurRadius: 22,
        offset: Offset(0, 12),
        spreadRadius: -18,
      ),
    ];
  }

  static List<BoxShadow> floating(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ];
    }
    return const [
      BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(
        color: Color(0x0a000000),
        blurRadius: 16,
        offset: Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Color(0x0f000000),
        blurRadius: 32,
        offset: Offset(0, 24),
        spreadRadius: -8,
      ),
    ];
  }
}

class AppGradients {
  static const mesh = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xff007cf0),
      Color(0xff00dfd8),
      Color(0xff7928ca),
      Color(0xffff0080),
      Color(0xffff4d4d),
      Color(0xfff9cb28),
    ],
    stops: [0, .2, .42, .62, .82, 1],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final page = AppColors.page(brightness);
  final surface = AppColors.surface(brightness);
  final surfaceSubtle = AppColors.surfaceSubtle(brightness);
  final text = AppColors.text(brightness);
  final muted = AppColors.textMuted(brightness);
  final border = AppColors.border(brightness);
  final primary = dark ? AppColors.canvas : AppColors.ink;
  final onPrimary = dark ? AppColors.ink : AppColors.canvas;

  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.ink,
    brightness: brightness,
  );
  final scheme = baseScheme.copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: surfaceSubtle,
    onSecondary: text,
    tertiary: AppColors.link,
    onTertiary: AppColors.canvas,
    error: AppColors.error,
    onError: AppColors.canvas,
    errorContainer: dark ? AppColors.darkErrorSoft : AppColors.errorSoft,
    onErrorContainer: dark ? const Color(0xffffb3b3) : AppColors.errorDeep,
    surface: surface,
    onSurface: text,
    surfaceContainerLowest: page,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: surfaceSubtle,
    surfaceContainerHighest: surfaceSubtle,
    onSurfaceVariant: muted,
    outline: border,
    outlineVariant: border,
    inverseSurface: dark ? AppColors.canvas : AppColors.ink,
    onInverseSurface: dark ? AppColors.ink : AppColors.canvas,
    inversePrimary: dark ? AppColors.ink : AppColors.canvas,
  );

  final textTheme = _textTheme(text, muted);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.lg),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
    borderSide: BorderSide(color: border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: page,
    colorScheme: scheme,
    fontFamily: 'Inter',
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: page,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: text, size: 20),
      actionsIconTheme: IconThemeData(color: text, size: 20),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: border.withValues(alpha: dark ? .9 : .78)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
      prefixIconColor: muted,
      suffixIconColor: muted,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 15,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: border.withValues(alpha: .7)),
      ),
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: primary, width: 1.2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: surfaceSubtle,
        disabledForegroundColor: muted,
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: border),
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: text,
        backgroundColor: surface,
        disabledForegroundColor: muted.withValues(alpha: .5),
        minimumSize: const Size.square(46),
        shape: CircleBorder(
          side: BorderSide(color: border.withValues(alpha: dark ? .9 : .82)),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: surfaceSubtle,
      shadowColor: Colors.transparent,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? text : muted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          height: 1.33,
          color: selected ? text : muted,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      extendedTextStyle: textTheme.labelLarge?.copyWith(color: onPrimary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: border.withValues(alpha: dark ? .9 : .78)),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      modalBackgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? AppColors.canvas : AppColors.ink,
      contentTextStyle: textTheme.bodySmall?.copyWith(
        color: dark ? AppColors.ink : AppColors.canvas,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: primary.withValues(alpha: dark ? .18 : .08),
      disabledColor: surfaceSubtle,
      labelStyle: textTheme.labelSmall,
      secondaryLabelStyle: textTheme.labelSmall?.copyWith(color: text),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: surfaceSubtle,
      circularTrackColor: surfaceSubtle,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      titleTextStyle: textTheme.bodySmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: textTheme.caption,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: shape,
    ),
  );
}

TextTheme _textTheme(Color text, Color muted) {
  return TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 48,
      fontWeight: FontWeight.w600,
      height: 1,
      letterSpacing: 0,
      color: text,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0,
      color: text,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: 0,
      color: text,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0,
      color: text,
    ),
    titleLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0,
      color: text,
    ),
    titleMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: text,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.43,
      letterSpacing: 0,
      color: text,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: text,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.43,
      letterSpacing: 0,
      color: muted,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.33,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Inter',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.43,
      color: text,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.33,
      color: text,
    ),
    labelSmall: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: muted,
    ),
  );
}

extension VercelTextTheme on TextTheme {
  TextStyle get caption => bodySmall!;

  TextStyle code(Color color) => TextStyle(
    fontFamily: 'JetBrains Mono',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.54,
    color: color,
  );
}
