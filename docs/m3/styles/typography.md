# Typography

> Source: [api.flutter.dev — TextTheme](https://api.flutter.dev/flutter/material/TextTheme-class.html). M3 type scale as Flutter applies it.

## Purpose

The type scale gives every text role a deliberate size, weight, and tracking so hierarchy is consistent across screens. Pick a role by what the text *does* (display, headline, title, body, label), not by what size you want.

## M3 reference scale

The values Flutter applies when `useMaterial3: true` and `Typography.material2021` is in effect:

| Role | Size | Line height | Weight | Letter spacing |
|---|---:|---:|---|---:|
| `displayLarge` | 57 | 64 | w400 | -0.25 |
| `displayMedium` | 45 | 52 | w400 | 0.0 |
| `displaySmall` | 36 | 44 | w400 | 0.0 |
| `headlineLarge` | 32 | 40 | w400 | 0.0 |
| `headlineMedium` | 28 | 36 | w400 | 0.0 |
| `headlineSmall` | 24 | 32 | w400 | 0.0 |
| `titleLarge` | 22 | 28 | w400 | 0.0 |
| `titleMedium` | 16 | 24 | w500 | 0.15 |
| `titleSmall` | 14 | 20 | w500 | 0.10 |
| `bodyLarge` | 16 | 24 | w400 | 0.50 |
| `bodyMedium` | 14 | 20 | w400 | 0.25 |
| `bodySmall` | 12 | 16 | w400 | 0.40 |
| `labelLarge` | 14 | 20 | w500 | 0.10 |
| `labelMedium` | 12 | 16 | w500 | 0.50 |
| `labelSmall` | 11 | 16 | w500 | 0.50 |

Sizes are in sp (logical pixels for Flutter); weights are `FontWeight` constants. `w400` is "regular", `w500` is "medium".

## Role intent (M3)

- **Display** — short, prominent text. Hero headers, marketing surfaces. Use sparingly.
- **Headline** — high-emphasis text for shorter paragraphs or screen titles.
- **Title** — medium-emphasis text used to introduce a region (card title, list section header).
- **Body** — running text, longer reading content.
- **Label** — call-to-action text on buttons, tabs, captions, metadata.

## In this project

The custom `TextTheme` lives in [`_textTheme()` at lib/core/theme/app_theme.dart:393](../../lib/core/theme/app_theme.dart#L393). It deviates from the M3 scale in deliberate ways:

| Role | Project | M3 default | Reason inferred from code |
|---|---|---|---|
| `displayLarge` | 48 / 1.0 / w600 | 57 / 64 / w400 | Smaller, tighter, heavier — closer to a "marketing hero" treatment. |
| `headlineLarge` | 32 / 1.25 / w600 | 32 / 40 / w400 | Same size, heavier weight. |
| `headlineMedium` | 24 / 1.33 / w600 | 28 / 36 / w400 | Reduced; w600. |
| `headlineSmall` | 20 / 1.4 / w600 | 24 / 32 / w400 | Reduced; w600. |
| `titleLarge` | 20 / 1.4 / w600 | 22 / 28 / w400 | Reduced; w600 — used in [`AppBarTheme.titleTextStyle` (line 207)](../../lib/core/theme/app_theme.dart#L207). |
| `titleMedium` | 16 / 1.5 / w500 | 16 / 24 / w500 | Matches M3. |
| `titleSmall` | 14 / 1.43 / w500 | 14 / 20 / w500 | Matches M3 size; height tighter. |
| `bodyLarge` | 16 / 1.5 / w400 | 16 / 24 / w400 | Matches M3. |
| `bodyMedium` | 14 / 1.43 / w400 / muted | 14 / 20 / w400 | Defaults to muted color. |
| `bodySmall` | 12 / 1.33 / w400 / muted | 12 / 16 / w400 | Defaults to muted color. |
| `labelLarge` | 14 / 1.43 / w500 | 14 / 20 / w500 | Matches M3. |
| `labelMedium` | 12 / 1.33 / w500 | 12 / 16 / w500 | Matches M3. |
| `labelSmall` | **JetBrains Mono** 11 / 1.45 / w400 | **Inter** 11 / 16 / w500 | **Repurposed** as the monospace token. |

### What's intentional

- **All weights one step heavier** through display/headline/title — the project favors a denser typographic feel.
- **`labelSmall` is the mono slot.** This is unusual but lets you read mono text via `theme.textTheme.labelSmall`. Anything that needs proper inline mono should use the `code(color)` extension instead — see below.
- **`bodyMedium` and `bodySmall` default to muted.** Useful in `ListTile` subtitles and metadata, but it means dropping a `Text` with these styles inline will quietly de-emphasize content. Override the color when you mean primary text.
- **`displaySmall` is unset** — calling `theme.textTheme.displaySmall` returns null in the project. Don't reach for it.

### Custom extension

[`VercelTextTheme` at lib/core/theme/app_theme.dart:496](../../lib/core/theme/app_theme.dart#L496) adds:

- `caption` — alias for `bodySmall`. Use when the call site is talking about captions, not body text.
- `code(Color color)` — JetBrains Mono / 13 / w400 / 1.54 line height. Use this for inline code, paths, IDs.

## Fonts

- **Inter** — primary sans, used for everything except `labelSmall` and `code(...)`. Loaded via `pubspec.yaml`. The `fontFamily: 'Inter'` is set on `ThemeData` ([line 197](../../lib/core/theme/app_theme.dart#L197)) so any `TextStyle` without an explicit family inherits it.
- **JetBrains Mono** — used by `labelSmall` and `code(...)`.

## Accessibility

- Body text scales with the OS text-size setting via Flutter's text scale factor. Don't fight this with hardcoded heights — use `height` (relative) not absolute line spacing.
- Maintain ≥ 4.5:1 contrast against the surface for body text, ≥ 3:1 for large text (≥ 18 sp regular or ≥ 14 sp w500). The muted defaults on `bodyMedium`/`bodySmall` (`#888` on `#fafafa` ≈ 4.6:1) are right at the line — verify with new background colors.

## Flutter mapping

| M3 role | Flutter API | Where set |
|---|---|---|
| `displayLarge`…`labelSmall` | `ThemeData.textTheme` | [`_textTheme()`](../../lib/core/theme/app_theme.dart#L393) |
| Default font | `ThemeData.fontFamily` | [line 197](../../lib/core/theme/app_theme.dart#L197) — `'Inter'` |
| AppBar title style | `AppBarTheme.titleTextStyle` | [line 207](../../lib/core/theme/app_theme.dart#L207) — `titleLarge` |
| Button label | `FilledButtonThemeData.style.textStyle` | [line 261](../../lib/core/theme/app_theme.dart#L261) — `labelLarge` |
| ListTile title | `ListTileThemeData.titleTextStyle` | [line 382](../../lib/core/theme/app_theme.dart#L382) — `bodySmall` (custom override) |
