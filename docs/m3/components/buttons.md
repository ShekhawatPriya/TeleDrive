# Buttons (Filled + FAB)

> Source: [Flutter source — `_FilledButtonDefaultsM3` in `filled_button.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/filled_button.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

Filled buttons sit second in the M3 emphasis ladder, just below the FAB. Use them for the primary, terminal action on a screen — the one the user is moving toward (Save, Confirm, Continue, Join). One per screen, ideally; if you find yourself reaching for two, one of them probably wants to be tonal/outlined/text.

The full M3 emphasis hierarchy:

```
FAB > FilledButton > FilledButton.tonal > ElevatedButton > OutlinedButton > TextButton
```

## FilledButton specs (M3 defaults)

| Property | Value |
|---|---|
| `minimumSize` | `64 × 40` |
| `maximumSize` | `Size.infinite` |
| `padding` | `EdgeInsets.symmetric(horizontal: 24)` (scales down to 12, then 6 with text scale) |
| `iconSize` | `18` |
| `iconAlignment` | `IconAlignment.start` (fallback) |
| `shape` | `StadiumBorder()` (pill) |
| `textStyle` | `textTheme.labelLarge` (14 / 20 / w500 / 0.10) |
| `animationDuration` | `kThemeChangeDuration` (200 ms) |
| `enableFeedback` | `true` |
| `mouseCursor` | `WidgetStateMouseCursor.adaptiveClickable` |

## State map

| State | Background | Foreground / Icon | Overlay | Elevation |
|---|---|---|---|---|
| Enabled | `primary` | `onPrimary` | — | 0 |
| Hovered | `primary` | `onPrimary` | `onPrimary @ 0.08` | 1 |
| Focused | `primary` | `onPrimary` | `onPrimary @ 0.10` | 0 |
| Pressed | `primary` | `onPrimary` | `onPrimary @ 0.10` | 0 |
| Disabled | `onSurface @ 0.12` | `onSurface @ 0.38` | — | 0 |

`shadowColor` = `shadow`; `surfaceTintColor` = transparent (M3 has phased out tint on filled surfaces).

## FAB specs (referenced)

`FloatingActionButton.extended` (the variant used in the app) defaults to:

| Property | Value |
|---|---|
| Container width | min 80 |
| Container height | 56 |
| Corner radius | 16 |
| Background | `primaryContainer` |
| Foreground | `onPrimaryContainer` |
| Elevation | 3 (resting), 4 (hovered/focused/pressed) |
| Label style | `textTheme.labelLarge` |
| Icon size | 24 |
| Icon-label gap | 12 |

(The standard FAB is 56×56 with a 16 dp radius; the small FAB is 40×40 with a 12 dp radius; the large FAB is 96×96 with a 28 dp radius.)

## Variants

| Variant | When to use |
|---|---|
| **Filled** | Primary, screen-terminal action. |
| **Filled tonal** | High but not max emphasis — when filled would be too loud against an already-busy surface. Background `secondaryContainer`, foreground `onSecondaryContainer`. |
| **Elevated** | Filled-with-shadow alternative for surfaces where the contrast against the background isn't strong enough on its own. |
| **Outlined** | Medium emphasis. Cancel buttons, secondary actions paired with a filled primary. |
| **Text** | Lowest emphasis. Inline links, dismiss/skip in dialogs, dense areas. |
| **FAB** | A single, screen-level shortcut to the most important create/compose action. |
| **FAB.extended** | Same role as FAB but with a label — clearer when the icon alone is ambiguous. |

## Accessibility

- Labels render in `labelLarge`. Don't substitute it with body styles — they have looser tracking and break button rhythm.
- Default `minimumSize` is 64 × 40, but `materialTapTargetSize` (default `padded`) inflates the tap target to 48 × 48 — don't override that without an accessibility reason.
- Hover state has `elevation: 1` — note that this is a real shadow, so disabling tint without overriding `shadowColor` will still leave a hover shadow visible.
- Disabled buttons reduce foreground to `onSurface @ 0.38` — that's at the WCAG floor for non-text UI, not for body text. Keep button labels short so this is sufficient.

## In this project

[`filledButtonTheme` at lib/core/theme/app_theme.dart:250-263](../../lib/core/theme/app_theme.dart#L250-L263):

```dart
backgroundColor: primary,                    // matches M3
foregroundColor: onPrimary,                  // matches M3
disabledBackgroundColor: surfaceSubtle,      // diverges: M3 uses onSurface @ 0.12
disabledForegroundColor: muted,              // diverges: M3 uses onSurface @ 0.38
minimumSize: Size.fromHeight(44),            // diverges: M3 uses (64, 40)
padding: horizontal: 16,                     // diverges: M3 uses 24
shape: pill (radius 100),                    // matches M3 StadiumBorder
textStyle: labelLarge,                       // matches M3
```

Used in:
- [`lib/features/share/ui/share_result_view.dart`](../../lib/features/share/ui/share_result_view.dart)
- [`lib/features/share/ui/create_share_sheet.dart`](../../lib/features/share/ui/create_share_sheet.dart)
- [`lib/features/drive/components/drive_dialogs.dart`](../../lib/features/drive/components/drive_dialogs.dart)
- [`lib/features/photos/ui/file_viewer_screen.dart`](../../lib/features/photos/ui/file_viewer_screen.dart)

### FAB (extended)

[`floatingActionButtonTheme` at lib/core/theme/app_theme.dart:318-329](../../lib/core/theme/app_theme.dart#L318-L329):

```dart
backgroundColor: primary,         // diverges: M3 uses primaryContainer
foregroundColor: onPrimary,       // diverges: M3 uses onPrimaryContainer
elevation: 0 (all states),        // diverges: M3 uses 3/4
shape: pill (radius 100),         // diverges: M3 uses 16dp on extended FAB
extendedTextStyle: labelLarge,    // matches M3
```

Used in [`lib/features/drive/components/drive_fab.dart`](../../lib/features/drive/components/drive_fab.dart).

The project chose primary/onPrimary over primaryContainer/onPrimaryContainer to keep the FAB visually consistent with the filled button. That's a deliberate trade — the project's monochrome scheme makes the M3 distinction less meaningful.

### Gaps

- **No state-layer overlays.** The theme doesn't define `overlayColor`, so the framework computes them from the M3 defaults table. That's fine for filled buttons but means hover/pressed states use M3 opacities (0.08 / 0.10) over `onPrimary`, not project tokens.
- **Hover elevation = 1 still active.** `surfaceTintColor: Colors.transparent` is set globally on cards/sheets/app bar but not on filled buttons. The hover shadow still paints. If the project wants flat buttons in all states, override `elevation` per-state in `filledButtonTheme`.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Container color | `ButtonStyle.backgroundColor` | [line 252](../../lib/core/theme/app_theme.dart#L252) |
| Label color | `ButtonStyle.foregroundColor` | [line 253](../../lib/core/theme/app_theme.dart#L253) |
| Container shape | `ButtonStyle.shape` | [line 258](../../lib/core/theme/app_theme.dart#L258) |
| Label typography | `ButtonStyle.textStyle` | [line 261](../../lib/core/theme/app_theme.dart#L261) |
| Container size | `ButtonStyle.minimumSize` | [line 256](../../lib/core/theme/app_theme.dart#L256) |
| Padding | `ButtonStyle.padding` | [line 257](../../lib/core/theme/app_theme.dart#L257) |
| Disabled colors | `disabledBackgroundColor` / `disabledForegroundColor` | [lines 254-255](../../lib/core/theme/app_theme.dart#L254-L255) |
