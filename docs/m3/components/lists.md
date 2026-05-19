# Lists (ListTile)

> Source: [Flutter source — `_LisTileDefaultsM3` in `list_tile.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/list_tile.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

A `ListTile` is one row in a list — leading visual, primary text, optional secondary text, optional trailing widget. M3 lists trade visual weight for scanability: most rows are one or two lines of text, with subtle icon coloring and no surface fill.

## Anatomy

```
┌──────────────────────────────────────────────────────────┐
│  [leading]    Title                          [trailing]  │
│               Subtitle (optional)                        │
└──────────────────────────────────────────────────────────┘
   16dp start                                  24dp end
   ↑           ↑                               ↑
   minLeading  horizontalTitleGap = 16         contentPadding.end
   = 24
```

## Specs (M3 defaults)

| Property | Value |
|---|---|
| `contentPadding` | `EdgeInsetsDirectional.only(start: 16, end: 24)` |
| `minLeadingWidth` | 24 |
| `minVerticalPadding` | 8 |
| `horizontalTitleGap` | 16 (with `visualDensity.horizontal × 2` added) |
| `shape` | `RoundedRectangleBorder()` (no radius) |
| `tileColor` | `transparent` |
| `selectedTileColor` | falls back to `transparent` |
| `iconColor` | `onSurfaceVariant` |
| `selectedColor` | `primary` |
| `titleTextStyle` | `bodyLarge` colored `onSurface` |
| `subtitleTextStyle` | `bodyMedium` colored `onSurfaceVariant` |
| `leadingAndTrailingTextStyle` | `labelSmall` colored `onSurfaceVariant` |

### Default heights (computed in render object, not the defaults class)

| Lines | Standard | Dense |
|---|---:|---:|
| 1 | 56 | 48 |
| 2 | 72 | 64 |
| 3 | 88 | 76 |

Plus `visualDensity.baseSizeAdjustment.dy`.

## States

| State | Title | Subtitle | Icon | Tile fill |
|---|---|---|---|---|
| Enabled | `onSurface` | `onSurfaceVariant` | `onSurfaceVariant` | `tileColor` (transparent) |
| Selected | `primary` (via `selectedColor`) | `primary` | `primary` | `selectedTileColor` (transparent → set per-tile) |
| Disabled | `theme.disabledColor` | `theme.disabledColor` | `theme.disabledColor` | unchanged |
| Hovered | unchanged | unchanged | unchanged | `onSurface @ 0.08` (state layer) |
| Focused | unchanged | unchanged | unchanged | `onSurface @ 0.10` |
| Pressed | unchanged | unchanged | unchanged | `onSurface @ 0.10` |

State layers apply when `enabled: true`. M3 selected tiles tint via `selectedTileColor` — typically `secondaryContainer` if you want the M3 look.

## Accessibility

- Tappable leading/trailing widgets must be ≥ 48 × 48. The framework caps their visual size at 32 (dense) or 40 (non-dense), and resolves the conflict by allowing the tile height to constrain them on one-line tiles.
- The default `minTileHeight` (56 dp for one-line) already satisfies the 48 dp tap target.
- Disabled tiles render text in `theme.disabledColor` — that's `onSurface @ 0.38` under M3, which is sub-WCAG for body text. Don't lean on disabled tiles for content the user must read.

## Variants

M3 doesn't define formal `ListTile` variants, but three patterns are common:

| Pattern | When |
|---|---|
| One-line | Single piece of info per row (file name, contact). Use `dense: true` for ≥ 8 rows on screen. |
| Two-line | Primary info + supporting metadata (file + size, contact + email). Default. |
| Three-line | Avoid unless you need a snippet preview. Prefer a custom row layout. |

## In this project

[`listTileTheme` at lib/core/theme/app_theme.dart:379-389](../../lib/core/theme/app_theme.dart#L379-L389):

```dart
iconColor: muted,                              // matches M3 onSurfaceVariant
textColor: text,                               // matches M3 onSurface
titleTextStyle: bodySmall + w500 + text,       // diverges: M3 uses bodyLarge
subtitleTextStyle: caption (= bodySmall),      // diverges: M3 uses bodyMedium
contentPadding: EdgeInsets.symmetric(horizontal: 18),  // diverges: M3 (start: 16, end: 24)
shape: RoundedRectangleBorder(radius: 20),     // diverges: M3 has no radius
```

The project pulls list tiles to a denser, smaller scale than M3:

- **Title is `bodySmall` (12 / 1.33), bumped to w500.** M3 uses `bodyLarge` (16 / 1.5). The result is a tighter, more compact list — appropriate for a file/folder browser where row count matters.
- **Subtitle is also `bodySmall`**, defaulting to muted color via the project's `bodySmall` style.
- **Tiles have a 20 dp corner radius.** M3 list tiles are square. The radius here matches the project card radius — visible when a tile gets a hover/pressed state layer or a custom background.
- **Symmetric padding (18 horizontal).** M3 uses asymmetric (16/24) because trailing widgets are typically larger.

Used in:
- [`lib/widgets/file_tiles.dart`](../../lib/widgets/file_tiles.dart) — every file/folder row
- [`lib/features/share/ui/access_log_list.dart`](../../lib/features/share/ui/access_log_list.dart) — share access log
- [`lib/features/upload/ui/components/upload_card.dart`](../../lib/features/upload/ui/components/upload_card.dart)
- 15 other files

### Selection behavior

The project's theme doesn't override `selectedColor` or `selectedTileColor`, so selection inherits the M3 defaults — selected text/icons turn `primary`, but with no tile fill. If selection ever needs a visible fill (multi-select mode in the file browser), set `selectedTileColor` per-tile or extend `listTileTheme`.

### Gaps

- **No `selectedTileColor`.** Multi-select can read as ambiguous since only the icon/text color shifts.
- **Subtitle and title use the same style.** M3's two-tier emphasis (bodyLarge / bodyMedium) collapses to one tier (bodySmall / bodySmall). Dense, but the visual difference between title and subtitle is carried by weight (w500 vs w400) and color (text vs muted) alone.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Title typography | `ListTileThemeData.titleTextStyle` | [line 382](../../lib/core/theme/app_theme.dart#L382) |
| Subtitle typography | `ListTileThemeData.subtitleTextStyle` | [line 386](../../lib/core/theme/app_theme.dart#L386) |
| Icon color | `ListTileThemeData.iconColor` | [line 380](../../lib/core/theme/app_theme.dart#L380) |
| Text color | `ListTileThemeData.textColor` | [line 381](../../lib/core/theme/app_theme.dart#L381) |
| Padding | `ListTileThemeData.contentPadding` | [line 387](../../lib/core/theme/app_theme.dart#L387) |
| Shape | `ListTileThemeData.shape` | [line 388](../../lib/core/theme/app_theme.dart#L388) |
