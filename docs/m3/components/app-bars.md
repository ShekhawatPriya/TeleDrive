# App bars

> Source: [Flutter source — `_AppBarDefaultsM3` in `app_bar.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/app_bar.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

The top app bar gives every screen a consistent header — title, leading affordance (back, menu), and trailing actions. M3 defines four scroll-aware variants:

| Variant | Layout |
|---|---|
| **Small** (`AppBar`) | Single row, title aligned with leading. The default. |
| **Center** | Single row, title centered (iOS-style). |
| **Medium** | Two-line: small title row + larger title underneath. Title shrinks to the small row when scrolled. |
| **Large** | Two-line with a taller bottom row. Same shrink behavior, more dramatic. |

## Specs — small (M3 defaults)

| Property | Value |
|---|---|
| `backgroundColor` | `surface` |
| `foregroundColor` | `onSurface` |
| `shadowColor` | `transparent` |
| `surfaceTintColor` | `transparent` (in defaults class; build falls back to `colorScheme.surfaceTint`) |
| `elevation` | 0 |
| `scrolledUnderElevation` | 3 |
| `toolbarHeight` | 64 |
| `titleSpacing` | `NavigationToolbar.kMiddleSpacing` (16) |
| `titleTextStyle` | `titleLarge` |
| `toolbarTextStyle` | `bodyMedium` |
| `iconTheme` | `IconThemeData(color: onSurface, size: 24)` |
| `actionsIconTheme` | `IconThemeData(color: onSurfaceVariant, size: 24)` |
| `actionsPadding` | `EdgeInsets.zero` |

`centerTitle` falls through to platform default — true on iOS/macOS when actions are absent or fewer than 2; false on Android, Fuchsia, Linux, Windows.

## Specs — medium (`SliverAppBar.medium`)

| Property | Value |
|---|---|
| `collapsedHeight` | 64 |
| `expandedHeight` | 112 |
| `collapsedTextStyle` | `titleLarge` colored `onSurface` |
| `expandedTextStyle` | `headlineSmall` colored `onSurface` |
| `expandedTitlePadding` | `EdgeInsets.fromLTRB(16, 0, 16, 20)` |

## Specs — large (`SliverAppBar.large`)

| Property | Value |
|---|---|
| `collapsedHeight` | 64 |
| `expandedHeight` | 152 |
| `collapsedTextStyle` | `titleLarge` colored `onSurface` |
| `expandedTextStyle` | `headlineMedium` colored `onSurface` |
| `expandedTitlePadding` | `EdgeInsets.fromLTRB(16, 0, 16, 28)` |

## Scroll-under behavior

The defining M3 app-bar interaction: when content scrolls under the bar, the bar shifts to a slightly elevated/tinted surface so the title stays legible. Implementation:

- `scrolledUnderElevation` controls the shadow level (default 3).
- `surfaceTintColor` controls the tonal overlay applied via `Material.surfaceTint`.

If you set `surfaceTintColor: Colors.transparent`, scroll-under produces only a shadow (none, if `scrolledUnderElevation` is also 0). The result is a flat bar that doesn't change on scroll — common in custom design systems but loses the M3 affordance.

## Title text scaling cap

The framework clamps title text scaling to `1.34` (`_kMaxTitleTextScaleFactor`). Beyond that, the title would push out the actions on small screens.

## Variants

| Variant | When |
|---|---|
| Small | Default. Use unless you have a reason to escalate. |
| Center | iOS feel; tabbed apps where the title represents the section. |
| Medium / Large | Hierarchical screens — the medium/large title doubles as a heading for the screen content. Most useful at the top of a navigation stack. |

## Accessibility

- The 64 dp toolbar height already satisfies the 48 dp tap target for leading/actions.
- Action icons use `onSurfaceVariant` (lower contrast than `onSurface`). If your scheme has low onSurface/onSurfaceVariant contrast, set `actionsIconTheme` explicitly.
- Provide a `tooltip` on every `IconButton` in actions — assistive tech relies on it for unlabeled icons.

## In this project

[`appBarTheme` at lib/core/theme/app_theme.dart:200-210](../../lib/core/theme/app_theme.dart#L200-L210):

```dart
backgroundColor: page,                     // diverges: M3 surface; project uses page (canvasSoft / darkCanvas)
foregroundColor: text,                     // matches M3 onSurface intent
surfaceTintColor: Colors.transparent,      // matches M3 defaults class (disables tonal overlay)
elevation: 0,                              // matches M3
scrolledUnderElevation: 0,                 // diverges: M3 = 3 (disables scroll-under affordance)
centerTitle: false,                        // matches M3 Android default
titleTextStyle: titleLarge,                // matches M3
iconTheme: IconThemeData(color: text, size: 20),         // diverges: M3 size 24
actionsIconTheme: IconThemeData(color: text, size: 20),  // diverges: M3 onSurfaceVariant + 24
```

Two intentional deviations:

- **Background = `page`, not `surface`.** The page color is `canvasSoft` (light) / `darkCanvas` (dark) — slightly off the surface. The bar visually merges with the scaffold background instead of sitting on its own surface tone.
- **No scroll-under affordance.** With both elevation and scroll-under elevation at 0, plus transparent tint, the bar never changes appearance during scroll. Content scrolls "under" by being below the toolbar height, but there's no tint, no shadow, no border. This is consistent with the project's flat aesthetic but removes a useful affordance — verify legibility when content scrolls right up to the title.

Used in 16 files across drive, photos, share, auth features.

### Conventions

- **`AppBar` (small) for everything.** No screen in the app currently uses medium or large.
- **Leading is back arrow or close**, drawn from the navigator. Custom leading widgets should keep the 48 × 48 hit area.
- **Actions in `onSurfaceVariant` (M3) but `text` (project)** — the project promotes actions to full-emphasis. Consider whether that's intentional or whether actions should be muted to match M3.

### Gaps

- **No clear "scrolled-under" treatment.** If the app ever needs a hairline divider when content scrolls under the bar, set `scrolledUnderElevation: 0` and add `bottom: PreferredSize(... border ...)` per-screen, or add a `Divider` after the app bar.
- **Icon size 20 vs M3 24.** Tap target is preserved by the `IconButton` (which inflates), but visual icons are smaller. Make sure new icon assets render legibly at 20.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Background | `AppBarTheme.backgroundColor` | [line 201](../../lib/core/theme/app_theme.dart#L201) |
| Foreground | `AppBarTheme.foregroundColor` | [line 202](../../lib/core/theme/app_theme.dart#L202) |
| Tint | `AppBarTheme.surfaceTintColor` | [line 203](../../lib/core/theme/app_theme.dart#L203) |
| Elevation | `AppBarTheme.elevation` | [line 204](../../lib/core/theme/app_theme.dart#L204) |
| Scroll-under | `AppBarTheme.scrolledUnderElevation` | [line 205](../../lib/core/theme/app_theme.dart#L205) |
| Center | `AppBarTheme.centerTitle` | [line 206](../../lib/core/theme/app_theme.dart#L206) |
| Title style | `AppBarTheme.titleTextStyle` | [line 207](../../lib/core/theme/app_theme.dart#L207) |
| Leading icons | `AppBarTheme.iconTheme` | [line 208](../../lib/core/theme/app_theme.dart#L208) |
| Action icons | `AppBarTheme.actionsIconTheme` | [line 209](../../lib/core/theme/app_theme.dart#L209) |
