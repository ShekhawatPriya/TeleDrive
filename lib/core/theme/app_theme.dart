import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tokens/app_color.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_motion.dart';
import 'tokens/app_shape.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_state.dart';
import 'tokens/app_typography.dart';
import 'ios_palette.dart';

// Re-export tokens so existing imports of `app_theme.dart` keep compiling.
export 'tokens/app_color.dart';
export 'ios_palette.dart' show iosGraphite;
export 'tokens/app_elevation.dart';
export 'tokens/app_motion.dart';
export 'tokens/app_shape.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_state.dart';
export 'tokens/app_typography.dart' show AppTextThemeExt, buildAppTextTheme;

/// Builds the app theme from a [ColorScheme]. Pass a seeded scheme directly
/// from [AppBrand.scheme] for consistent light, dark and high-contrast roles.
ThemeData buildTheme(ColorScheme scheme) {
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  if (ios) scheme = iosPalette(scheme);
  final textTheme = buildAppTextTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    brightness: scheme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    splashFactory: ios ? NoSplash.splashFactory : InkRipple.splashFactory,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: scheme.brightness,
      primaryColor: scheme.primary,
      primaryContrastingColor: scheme.onPrimary,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: CupertinoTextThemeData(primaryColor: scheme.primary),
    ),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: ios,
      toolbarHeight: ios ? 56 : 64,
      titleSpacing: AppSpacing.md,
      titleTextStyle: ios
          ? textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
          : textTheme.titleLarge,
      iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    ),

    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: 0,
      margin: const EdgeInsets.all(AppSpacing.xxs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ios ? 24 : 28),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: AppSpacing.md,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: textTheme.bodySmall?.copyWith(color: scheme.primary),
      helperStyle: textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(color: scheme.outline),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(
          color: scheme.onSurface.withValues(
            alpha: AppStateLayer.disabledContainer,
          ),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadii.smR,
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.onSurface.withValues(
          alpha: AppStateLayer.disabledContainer,
        ),
        disabledForegroundColor: scheme.onSurface.withValues(
          alpha: AppStateLayer.disabledContent,
        ),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
        animationDuration: AppDurations.short4,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        disabledForegroundColor: scheme.onSurface.withValues(
          alpha: AppStateLayer.disabledContent,
        ),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: BorderSide(color: scheme.outline),
        textStyle: textTheme.labelLarge,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      elevation: AppElevation.level2,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
          size: 24,
        );
      }),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: AppElevation.level3,
      focusElevation: AppElevation.level3,
      hoverElevation: AppElevation.level4,
      highlightElevation: AppElevation.level3,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.lgR),
      extendedTextStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onPrimaryContainer,
      ),
      iconSize: 24,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shadowColor: scheme.shadow,
      elevation: AppElevation.level3,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xlR),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      modalBackgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: AppElevation.level1,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      clipBehavior: Clip.antiAlias,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant,
      dragHandleSize: const Size(32, 4),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      elevation: AppElevation.level3,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smR),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      disabledColor: scheme.onSurface.withValues(
        alpha: AppStateLayer.disabledContainer,
      ),
      labelStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 4,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      contentPadding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        0,
        AppSpacing.lg,
        0,
      ),
      shape: const RoundedRectangleBorder(),
      tileColor: Colors.transparent,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.titleSmall,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
    ),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(
            alpha: AppStateLayer.disabledContainer,
          );
        }
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(scheme.onPrimary),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.transparent;
        return scheme.outline;
      }),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: AppRadii.smR,
      ),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      preferBelow: true,
      verticalOffset: 24,
      waitDuration: const Duration(milliseconds: 500),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level2,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smR),
      textStyle: textTheme.bodyLarge,
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(scheme.surfaceContainer),
        surfaceTintColor: WidgetStateProperty.all(scheme.surfaceTint),
        shadowColor: WidgetStateProperty.all(scheme.shadow),
        elevation: WidgetStateProperty.all(AppElevation.level2),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: AppRadii.smR),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        ),
      ),
    ),

    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStateProperty.all(scheme.surfaceContainerHigh),
      elevation: WidgetStateProperty.all(AppElevation.level0),
      shadowColor: WidgetStateProperty.all(Colors.transparent),
      surfaceTintColor: WidgetStateProperty.all(scheme.surfaceTint),
      shape: WidgetStateProperty.all(const StadiumBorder()),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      hintStyle: WidgetStateProperty.all(
        textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      textStyle: WidgetStateProperty.all(textTheme.bodyLarge),
      constraints: const BoxConstraints(minHeight: 56),
    ),

    searchViewTheme: SearchViewThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: AppElevation.level3,
      headerHintStyle: textTheme.bodyLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      headerTextStyle: textTheme.bodyLarge,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.smR),
      dividerColor: scheme.outlineVariant,
    ),

    extensions: [
      AppMotion(
        durationShort: AppDurations.short4,
        durationMedium: AppDurations.medium2,
        durationLong: AppDurations.long1,
        emphasized: AppEasing.emphasized,
      ),
    ],
  );
}

/// `ThemeExtension` carrying canonical motion durations / curves so call
/// sites can pull them from `Theme.of(context).extension<AppMotion>()`
/// instead of repeating literals.
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.durationShort,
    required this.durationMedium,
    required this.durationLong,
    required this.emphasized,
  });

  final Duration durationShort;
  final Duration durationMedium;
  final Duration durationLong;
  final Curve emphasized;

  @override
  AppMotion copyWith({
    Duration? durationShort,
    Duration? durationMedium,
    Duration? durationLong,
    Curve? emphasized,
  }) {
    return AppMotion(
      durationShort: durationShort ?? this.durationShort,
      durationMedium: durationMedium ?? this.durationMedium,
      durationLong: durationLong ?? this.durationLong,
      emphasized: emphasized ?? this.emphasized,
    );
  }

  @override
  AppMotion lerp(ThemeExtension<AppMotion>? other, double t) => this;
}
