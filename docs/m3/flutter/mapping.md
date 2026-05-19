# M3 → Flutter cheatsheet

> One-page lookup: M3 token → Flutter API → where it's set in this project.

For deeper context on any row, follow the link in the right column.

## Theme entry points

| Concern | Where it's wired up |
|---|---|
| `useMaterial3` | [`lib/core/theme/app_theme.dart:193`](../../lib/core/theme/app_theme.dart#L193) |
| Light/dark themes | [`buildTheme(brightness)` at lib/core/theme/app_theme.dart:142](../../lib/core/theme/app_theme.dart#L142) |
| Theme applied | [`lib/app.dart`](../../lib/app.dart) lines 94-96 |

## Color

| M3 role | Flutter property | Project value |
|---|---|---|
| `primary` | `ColorScheme.primary` | `AppColors.ink` (light) / `AppColors.canvas` (dark) |
| `onPrimary` | `ColorScheme.onPrimary` | inverse of primary |
| `secondary` | `ColorScheme.secondary` | `surfaceSubtle` (intentionally muted) |
| `tertiary` | `ColorScheme.tertiary` | `AppColors.link` (#0070f3) — the project's true accent |
| `error` | `ColorScheme.error` | `AppColors.error` (#ee0000) |
| `surface` | `ColorScheme.surface` | `AppColors.canvas` / `darkSurface` |
| `surfaceContainerLow/Container/High/Highest` | same | mostly aliased to surface or surfaceSubtle (flat hierarchy) |
| `onSurface` | `ColorScheme.onSurface` | `text` (= `ink` / `canvas`) |
| `onSurfaceVariant` | `ColorScheme.onSurfaceVariant` | `mute` / `darkMute` |
| `outline` | `ColorScheme.outline` | `hairline` / `darkHairline` |
| `outlineVariant` | `ColorScheme.outlineVariant` | same as `outline` (collision) |
| `inverseSurface` | `ColorScheme.inverseSurface` | inverse `ink`/`canvas` |
| `surfaceTint` | not set | turned off via per-component `surfaceTintColor: transparent` |

→ [styles/color.md](../styles/color.md)

## Typography

| M3 role | Flutter property | Project size / weight |
|---|---|---|
| `displayLarge` | `textTheme.displayLarge` | 48 / w600 (M3: 57 / w400) |
| `displayMedium` / `displaySmall` | not set | — |
| `headlineLarge/Medium/Small` | `textTheme.headlineLarge/Medium/Small` | 32 / 24 / 20, w600 |
| `titleLarge/Medium/Small` | `textTheme.titleLarge/Medium/Small` | 20 / 16 / 14 |
| `bodyLarge/Medium/Small` | `textTheme.bodyLarge/Medium/Small` | 16 / 14 / 12 (`bodyMedium`/`bodySmall` default to muted color) |
| `labelLarge/Medium` | `textTheme.labelLarge/Medium` | 14 / 12, w500 |
| `labelSmall` | `textTheme.labelSmall` | **JetBrains Mono** 11 / w400 — repurposed as mono token |
| Custom mono | `textTheme.code(color)` extension | 13 / w400 / 1.54 |

Set in [`_textTheme()` at lib/core/theme/app_theme.dart:393](../../lib/core/theme/app_theme.dart#L393). → [styles/typography.md](../styles/typography.md)

## Shape

| M3 token | Flutter shape | Project token |
|---|---|---|
| Buttons (stadium) | `StadiumBorder()` / radius 100 | `AppRadii.pill` |
| Card (12) | `RoundedRectangleBorder(radius: 12)` | `AppRadii.lg` (20) |
| Sheet top (28) | `BorderRadius.vertical(top: 28)` | `AppRadii.sheet` (28) |
| Dialog (28) | `RoundedRectangleBorder(radius: 28)` | `AppRadii.xl` (24) |
| Snackbar (4) | `RoundedRectangleBorder(radius: 4)` | `AppRadii.lg` (20) |
| FAB (16) | `RoundedRectangleBorder(radius: 16)` | `AppRadii.pill` (100) |
| Text field (≈ 4) | `OutlineInputBorder(radius: ...)` | `AppRadii.md` (16) |

→ [styles/shape.md](../styles/shape.md)

## Elevation

| M3 level | Flutter `elevation` | Project equivalent |
|---|---:|---|
| 0 | 0 | default (no shadow) |
| 1 (card, sheet) | 1 | `AppShadows.card(brightness)` if needed |
| 3 (dialog, snackbar, FAB resting) | 6 | `AppShadows.floating(brightness)` |
| 4 (FAB hover) | 8 | not implemented |

`surfaceTintColor: Colors.transparent` is set on `AppBarTheme`, `CardThemeData`, `BottomSheetThemeData`, `DialogThemeData`, `NavigationBarThemeData`, etc. → [styles/elevation.md](../styles/elevation.md)

## State layers

| State | Opacity (M3) | Notes |
|---|---:|---|
| Hovered | 0.08 | over foreground role |
| Focused | 0.10 | priority on text fields |
| Pressed | 0.10 | + ripple |
| Dragged | 0.16 | switch thumb, slider, FAB drag |

Project doesn't override `overlayColor` — inherits M3 defaults. → [styles/state-layers.md](../styles/state-layers.md)

## Motion

| M3 token | Suggested Flutter | Where used |
|---|---|---|
| Emphasized decelerate | `Curves.easeOutCubic` | sheet/dialog entry |
| Emphasized accelerate | `Curves.easeInCubic` | sheet/dialog exit |
| Standard | `Curves.easeInOut` | toggle, drag |
| Short 4 | 200 ms | small modal in/out |
| Medium 1 | 250 ms | snackbar, sheet exit |
| Medium 2 | 300 ms | sheet/dialog entry |
| Long 1 | 450 ms | full-screen transition |

Currently scattered as literals (`260`, `180`, `320` ms) — see [styles/motion.md](../styles/motion.md) for the recommended `MotionDurations` / `MotionCurves` consolidation.

## Components

| Component | Theme entry | Doc |
|---|---|---|
| AppBar | `AppBarTheme` ([line 200](../../lib/core/theme/app_theme.dart#L200)) | [components/app-bars.md](../components/app-bars.md) |
| Card | `CardThemeData` ([line 211](../../lib/core/theme/app_theme.dart#L211)) | [components/cards.md](../components/cards.md) |
| Divider | `DividerThemeData` ([line 223](../../lib/core/theme/app_theme.dart#L223)) | [components/divider.md](../components/divider.md) |
| TextField | `InputDecorationTheme` ([line 224](../../lib/core/theme/app_theme.dart#L224)) | [components/text-fields.md](../components/text-fields.md) |
| FilledButton | `FilledButtonThemeData` ([line 250](../../lib/core/theme/app_theme.dart#L250)) | [components/buttons.md](../components/buttons.md) |
| OutlinedButton | `OutlinedButtonThemeData` ([line 264](../../lib/core/theme/app_theme.dart#L264)) | [components/buttons.md](../components/buttons.md) |
| TextButton | `TextButtonThemeData` ([line 276](../../lib/core/theme/app_theme.dart#L276)) | [components/buttons.md](../components/buttons.md) |
| IconButton | `IconButtonThemeData` ([line 285](../../lib/core/theme/app_theme.dart#L285)) | — |
| NavigationBar | `NavigationBarThemeData` ([line 296](../../lib/core/theme/app_theme.dart#L296)) | (not in use) |
| FAB | `FloatingActionButtonThemeData` ([line 318](../../lib/core/theme/app_theme.dart#L318)) | [components/fab.md](../components/fab.md) |
| Dialog | `DialogThemeData` ([line 330](../../lib/core/theme/app_theme.dart#L330)) | [components/dialogs.md](../components/dialogs.md) |
| BottomSheet | `BottomSheetThemeData` ([line 339](../../lib/core/theme/app_theme.dart#L339)) | [components/bottom-sheets.md](../components/bottom-sheets.md) |
| SnackBar | `SnackBarThemeData` ([line 352](../../lib/core/theme/app_theme.dart#L352)) | [components/snackbar.md](../components/snackbar.md) |
| Chip | `ChipThemeData` ([line 363](../../lib/core/theme/app_theme.dart#L363)) | (not in use) |
| Progress | `ProgressIndicatorThemeData` ([line 374](../../lib/core/theme/app_theme.dart#L374)) | [components/progress-indicators.md](../components/progress-indicators.md) |
| ListTile | `ListTileThemeData` ([line 379](../../lib/core/theme/app_theme.dart#L379)) | [components/lists.md](../components/lists.md) |
| Checkbox | not themed (M3 defaults) | [components/checkbox.md](../components/checkbox.md) |
| Tooltip | not themed | [components/tooltip.md](../components/tooltip.md) |

## Spacing tokens

| Token | dp | Use |
|---|---:|---|
| `AppSpacing.xxs` | 4 | inline gaps |
| `AppSpacing.xs` | 8 | tight padding |
| `AppSpacing.sm` | 12 | compact components |
| `AppSpacing.md` | 16 | screen edge gutter, card padding |
| `AppSpacing.lg` | 24 | section break |
| `AppSpacing.xl` | 32 | major section break |
| `AppSpacing.xxl` | 40 | top-of-screen breathing room |

→ [foundations/layout.md](../foundations/layout.md)

## When you're stuck

| Question | Answer |
|---|---|
| What's the right corner radius for X? | [styles/shape.md](../styles/shape.md) — pick from `AppRadii` |
| Which color role for X? | [styles/color.md](../styles/color.md) — start with `surface` / `onSurface` / `primary` |
| What text style for X? | [styles/typography.md](../styles/typography.md) — pick by *role*, not size |
| Why does my button look wrong? | [components/buttons.md](../components/buttons.md) — check the project's overrides vs M3 |
| Sheet animation feels off? | [styles/motion.md](../styles/motion.md) — emphasized-decelerate at 300 ms |
| Disabled state too dim? | [foundations/interaction-states.md](../foundations/interaction-states.md) — that's M3's `0.38` opacity |
