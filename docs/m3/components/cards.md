# Card

> Source: [Flutter source — `_CardDefaultsM3`, `_FilledCardDefaultsM3`, `_OutlinedCardDefaultsM3` in `card.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/card.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

Cards group related content into a single tap target. They're for things you'd describe with a noun (a file, a folder, a contact, an album) — not for loose containers or section breaks. M3 has three variants with the same shape and typography, differing only in surface treatment.

## Specs (M3 defaults, all three variants)

| Property | Elevated (default) | Filled | Outlined |
|---|---|---|---|
| Corner radius | 12 dp | 12 dp | 12 dp |
| `clipBehavior` | `Clip.none` | `Clip.none` | `Clip.none` |
| `margin` | `EdgeInsets.all(4)` | `EdgeInsets.all(4)` | `EdgeInsets.all(4)` |
| `color` | `surfaceContainerLow` | `surfaceContainerHighest` | `surface` |
| `shadowColor` | `shadow` | `shadow` | `shadow` |
| `surfaceTintColor` | `transparent` | `transparent` | `transparent` |
| `elevation` | 1 | 0 | 0 |
| Border | none | none | `BorderSide(color: outlineVariant)` |

The M3 corner radius is 12 dp across all card variants. (Pre-M3 was 4 dp.) Surface tint is intentionally transparent in current M3 — the surface containers themselves carry the elevation cue, not a tonal overlay.

## Variants

| Variant | Use when |
|---|---|
| **Elevated** | The card needs to lift off the surface — list of distinct items on a low-emphasis background, or a single feature card. |
| **Filled** | The card sits in a content-heavy area where elevation would compete. Filled gives separation by color alone. |
| **Outlined** | Maximum information density — the outline draws the boundary without consuming a surface tone or shadow. Common in lists where every row is a card. |

## States

Cards aren't interactive by default. To make a card tappable, wrap its content in `InkWell` or `InkResponse` so the splash and state layers paint inside the rounded shape (Card sets `borderOnForeground: true` so the border draws over its child, but the child is still where the ink goes). State-layer opacities to apply on `InkWell.overlayColor` over `onSurface`:

| State | Opacity |
|---|---|
| Hovered | 0.08 |
| Focused | 0.10 |
| Pressed | 0.10 |
| Dragged | 0.16 |

## Accessibility

- Content padding inside a card is up to you — M3 doesn't mandate it. Keep an internal 16 dp gutter unless the card is dense by design.
- Tappable cards must meet 48 × 48 minimum target. A short list-style card with a 56 dp `ListTile` inside satisfies this.
- For outlined cards, the outline is `outlineVariant` — decorative, not contrast-required. If the border is the only thing distinguishing the card from its background, switch to `outline` (3:1 contrast) or use a filled variant.

## In this project

[`cardTheme` at lib/core/theme/app_theme.dart:211-222](../../lib/core/theme/app_theme.dart#L211-L222):

```dart
elevation: 0,                                          // diverges: M3 elevated = 1
color: surface,                                        // matches M3 outlined (surface)
surfaceTintColor: Colors.transparent,                  // matches M3
shadowColor: Colors.transparent,                       // diverges: M3 = shadow
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadii.lg),    // 20 dp — diverges from M3 12 dp
  side: BorderSide(color: border, alpha: 0.78-0.9),    // matches outlined intent
),
clipBehavior: Clip.antiAlias,                          // diverges: M3 = Clip.none
margin: EdgeInsets.zero,                               // diverges: M3 = EdgeInsets.all(4)
```

The project's card is effectively M3 **outlined**, with bigger corners (20 vs 12) and zero margin (the parent decides spacing instead of the card). The `clipBehavior: Clip.antiAlias` is a deliberate choice — needed because content (file thumbnails, gradients) commonly fills the card edge-to-edge.

Used in:
- [`lib/widgets/file_tiles.dart`](../../lib/widgets/file_tiles.dart) — `FileCardTile`, `FileListTile`
- [`lib/features/upload/ui/components/upload_card.dart`](../../lib/features/upload/ui/components/upload_card.dart)
- 22 other files

### Custom wrappers

- **`FileCardTile`** ([lib/widgets/file_tiles.dart](../../lib/widgets/file_tiles.dart)) — grid-style file card with thumbnail, name, metadata
- **`FileListTile`** ([lib/widgets/file_tiles.dart](../../lib/widgets/file_tiles.dart)) — row-style file card; uses `Card` as the boundary, `ListTile` semantics inside

### Gaps

- **No filled or elevated variant defined.** Every card in the app uses the same outlined-style theme. If a screen ever needs an elevated card (e.g., a "highlighted" item in a list), it'll need to be styled inline.
- **Corner radius hardcoded to `AppRadii.lg` (20 dp).** This is the project's chosen card size; document it in [styles/shape.md](../styles/shape.md) and treat 20 as the project card token.

## Flutter mapping

| M3 token | Flutter property | Project value |
|---|---|---|
| Container | `Card` | — |
| Surface color | `CardThemeData.color` | `surface` |
| Corner | `CardThemeData.shape` (radius) | `AppRadii.lg` (20 dp) |
| Border | `CardThemeData.shape.side` | `outline @ 0.78-0.9` |
| Elevation | `CardThemeData.elevation` | `0` (project) / `1` (M3 elevated) |
| Margin | `CardThemeData.margin` | `EdgeInsets.zero` |
| Clip | `CardThemeData.clipBehavior` | `Clip.antiAlias` |
