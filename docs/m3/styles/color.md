# Color

> Source: [api.flutter.dev — ColorScheme](https://api.flutter.dev/flutter/material/ColorScheme-class.html). The M3 color system as implemented by Flutter.

## Purpose

The color system gives every UI surface a role with a known contrast partner. You don't pick "a blue"; you pick `primary` (and the framework gives you `onPrimary` to draw on top of it with guaranteed legibility). Every `on*` color is contrast-paired with its base color at ≥ 4.5:1.

## Roles

### Primary group

| Role | Use |
|---|---|
| `primary` | The most-used accent. Filled buttons, FAB background, active indicators. |
| `onPrimary` | Text/icons drawn on `primary`. |
| `primaryContainer` | Less emphasis than `primary`. Background for prominent components that aren't the main action. |
| `onPrimaryContainer` | Text/icons on `primaryContainer`. |
| `primaryFixed` | Same color in light and dark themes — useful for elements that must not invert across modes. Pairs with `onPrimaryFixed` / `onPrimaryFixedVariant`. |
| `primaryFixedDim` | Higher-emphasis sibling of `primaryFixed`. |
| `onPrimaryFixed` | Text/icons on `primaryFixed` and `primaryFixedDim`. |
| `onPrimaryFixedVariant` | Lower-emphasis text/icons on the fixed surfaces. |

### Secondary group

`secondary` is a less prominent accent (filter chips, the second-tier button). Same shape as the primary group: `secondary`, `onSecondary`, `secondaryContainer`, `onSecondaryContainer`, plus the four fixed variants.

### Tertiary group

Contrasting accent meant to balance primary and secondary or pull attention to a single element (an input field). Same six-role shape as the secondary group, plus the four fixed variants.

### Error group

| Role | Use |
|---|---|
| `error` | Validation and error states (e.g. `InputDecoration.errorText`). |
| `onError` | Text/icons on `error`. |
| `errorContainer` | Lower-emphasis error surface. |
| `onErrorContainer` | Text/icons on `errorContainer`. |

### Surface and surface containers

| Role | Use |
|---|---|
| `surface` | Background for widgets like `Scaffold`. |
| `onSurface` | Default text/icons on `surface`. |
| `onSurfaceVariant` | Lower-emphasis text/icons (helper text, captions, inactive icons). |
| `surfaceDim` | Always the darkest tone in either theme. |
| `surfaceBright` | Always the brightest tone in either theme. |
| `surfaceContainerLowest` | Least emphasis vs `surface`. |
| `surfaceContainerLow` | One step up. |
| `surfaceContainer` | Recommended for distinct areas inside a surface. |
| `surfaceContainerHigh` | Higher emphasis. |
| `surfaceContainerHighest` | Most emphasis vs `surface`. |
| `surfaceTint` | Overlay color used to indicate elevation. **Off in this project** — see [styles/elevation.md](elevation.md). |
| `surfaceVariant` | Deprecated; use `surfaceContainerHighest`. |

### Inverse

| Role | Use |
|---|---|
| `inverseSurface` | A surface with reversed luminance — used by snackbars to stand out against the rest of the UI. |
| `onInverseSurface` | Text/icons on `inverseSurface`. |
| `inversePrimary` | Action color on inverse surfaces (e.g. snackbar action label). |

### Outlines, scrim, shadow

| Role | Use |
|---|---|
| `outline` | Borders that need to be perceivable (3:1 contrast required). |
| `outlineVariant` | Decorative borders/dividers — 3:1 not required. |
| `scrim` | Fill behind modal components. |
| `shadow` | Drop shadow color. |

### Deprecated

`background` / `onBackground` were merged into `surface` / `onSurface` in M3. Don't use them in new code.

## In this project

The scheme is built in [`buildTheme()` at lib/core/theme/app_theme.dart:142](../../lib/core/theme/app_theme.dart#L142). It starts with `ColorScheme.fromSeed(seedColor: AppColors.ink)` and then `copyWith()`s every role to lock in the project's monochrome ink-on-canvas identity. Highlights:

- `primary` = ink (light) / canvas (dark) — fully inverted across modes (lib/core/theme/app_theme.dart:150-151)
- `tertiary` = `AppColors.link` (#0070f3) — used as the project's true accent (lib/core/theme/app_theme.dart:162)
- `secondary` = surface-subtle, intentionally muted (lib/core/theme/app_theme.dart:160)
- `surfaceContainer` and `surfaceContainerLow` both alias to `surface` — flatter hierarchy than M3 default (lib/core/theme/app_theme.dart:171-172)
- `surfaceTint` not customized; `surfaceTintColor: Colors.transparent` is set on individual themes (`AppBarTheme`, `CardThemeData`, `BottomSheetThemeData`, etc.) to disable elevation tint

### Custom palette layered on top

[`AppColors`](../../lib/core/theme/app_theme.dart#L3-L53) defines a parallel set of named tokens (`ink`, `canvas`, `link`, `error`, `mute`, `hairline`, etc.) plus brightness-aware helpers (`page()`, `surface()`, `border()`, `text()`, `textMuted()`). These are the actual values the `ColorScheme` is built from. Prefer the `colorScheme` role in widgets where it works; reach for `AppColors` only when the role doesn't fit (e.g., `AppColors.link` for an inline link inside body text).

### Gaps vs. M3

- **No semantic alias layer.** `tertiary` is the project's accent but the name doesn't say so. A `ThemeExtension` (e.g. `AppPalette` with `link`, `success`, `warning`, `code`) would be clearer than reusing M3 roles for app-specific meanings.
- **Surface containers collapse.** `surfaceContainerLow` through `surfaceContainerHigh` are nearly identical. Fine for the current flat design, but rules out future "elevation by tone" work without a refactor.
- **`outline` and `outlineVariant` are the same.** M3 expects `outline` to meet 3:1 contrast and `outlineVariant` not to. Using the same value for both means decorative dividers and meaningful borders are indistinguishable.

## Flutter mapping

| M3 role | Flutter API | Project value |
|---|---|---|
| `primary` | `ColorScheme.primary` | `AppColors.ink` (light) / `AppColors.canvas` (dark) |
| `onPrimary` | `ColorScheme.onPrimary` | inverse of primary |
| `tertiary` | `ColorScheme.tertiary` | `AppColors.link` |
| `error` | `ColorScheme.error` | `AppColors.error` (#ee0000) |
| `surface` | `ColorScheme.surface` | `AppColors.canvas` (light) / `darkSurface` (dark) |
| `onSurfaceVariant` | `ColorScheme.onSurfaceVariant` | `AppColors.mute` (#888) / `darkMute` (#8f8f8f) |
| `outline` | `ColorScheme.outline` | `AppColors.hairline` (#ebebeb) / `darkHairline` (#2e2e2e) |
| `inverseSurface` | `ColorScheme.inverseSurface` | inverse ink/canvas |

Set globally in [lib/core/theme/app_theme.dart:153-181](../../lib/core/theme/app_theme.dart#L153-L181).
