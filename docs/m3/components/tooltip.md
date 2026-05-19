# Tooltip

> Source: [Flutter source — `tooltip.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/tooltip.dart). Note: Flutter's `Tooltip` doesn't ship a dedicated `_TooltipDefaultsM3` class — defaults are computed inline based on theme brightness and platform. The values here come from `_defaultXxx` constants and `_getDefaultXxx` helpers in the source.

## Purpose

A tooltip explains an icon-only control on long-press (mobile) or hover (desktop). One short phrase, no actions, no rich content. If the explanation is essential to use the control, the control needs a label, not a tooltip.

## Specs (defaults)

| Property | Value |
|---|---|
| `verticalOffset` | 24 |
| `preferBelow` | `true` |
| `margin` | `EdgeInsets.zero` |
| `waitDuration` | `Duration.zero` |
| `showDuration` | 1500 ms |
| `exitDuration` | 100 ms |
| `triggerMode` | `TooltipTriggerMode.longPress` |
| `textAlign` | `TextAlign.start` |
| `excludeFromSemantics` | `false` |
| `enableFeedback` | `true` |

### Platform-conditional

| Property | Desktop (macOS/Linux/Windows) | Mobile (Android/Fuchsia/iOS) |
|---|---|---|
| Min height | 24 | 32 |
| Padding | `symmetric(horizontal: 8, vertical: 4)` | `symmetric(horizontal: 16, vertical: 4)` |
| Font size | 12 | 14 |

### Brightness-conditional (built in `TooltipState.build`)

| Property | Light theme | Dark theme |
|---|---|---|
| Text color | `Colors.white` | `Colors.black` |
| Background | `Colors.grey[700].withOpacity(0.9)` | `Colors.white.withOpacity(0.9)` |
| Corner | `BorderRadius.all(Radius.circular(4))` | same |
| Text style base | `textTheme.bodyMedium` | same |

Note: tooltip uses the legacy `Colors` palette, not `ColorScheme`. The "M3 inverse-surface" appearance you'd expect from `inverseSurface`/`onInverseSurface` isn't applied automatically — supply a custom `decoration` and `textStyle` if you want that.

## Variants

M3 distinguishes:

| Variant | When |
|---|---|
| **Plain tooltip** (the default) | Short text label for an icon. |
| **Rich tooltip** (`Tooltip.rich` doesn't exist; build with `OverlayEntry` or `MenuAnchor`) | Multiline content with optional title and dismiss action. The framework doesn't ship this — implement with a custom overlay if needed. |

## Accessibility

- The tooltip text is read by assistive tech when the wrapped widget is focused. **Always set `tooltip` on icon-only `IconButton`s** — that's the screen-reader label.
- `triggerMode: longPress` on mobile means a tap doesn't show the tooltip — only long-press does. Don't put critical info in tooltips. Use them for "extra" hints.
- Don't rely on tooltips for keyboard users — focus a button and the tooltip will appear, but only after the wait. Better: a visible label.

## In this project

No `tooltipTheme` is set in [app_theme.dart](../../lib/core/theme/app_theme.dart). Tooltips render with framework defaults, including the legacy gray/white palette. Used in [`lib/widgets/ios_menu/ios_more_button.dart`](../../lib/widgets/ios_menu/ios_more_button.dart).

### Conventions

- **Set `tooltip:` on every `IconButton`.** That's the accessibility contract.
- **One-word or short-phrase tooltips.** "Delete", "More", "Share". Not "Tap to share with another user".

### Gaps

- **No theme override.** Tooltip styling doesn't match the project — it uses gray on white instead of ink/canvas. If the project ever cares about tooltip appearance, add a `tooltipTheme`:
  ```dart
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: dark ? AppColors.canvas : AppColors.ink,
      borderRadius: BorderRadius.circular(AppRadii.xs),
    ),
    textStyle: textTheme.labelMedium?.copyWith(
      color: dark ? AppColors.ink : AppColors.canvas,
    ),
    waitDuration: const Duration(milliseconds: 400),
  )
  ```

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Background | `TooltipThemeData.decoration` | not themed |
| Text style | `TooltipThemeData.textStyle` | not themed |
| Padding | `TooltipThemeData.padding` | not themed (platform default) |
| Wait | `TooltipThemeData.waitDuration` | not themed (default 0) |
| Show | `TooltipThemeData.showDuration` | not themed (default 1500ms) |
| Trigger | `TooltipThemeData.triggerMode` | not themed (default longPress) |
