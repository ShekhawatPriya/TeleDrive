# Divider

> Source: [Flutter source — `_DividerDefaultsM3` in `divider.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/divider.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

A horizontal line that separates content. Use sparingly — too many dividers make a screen look like a spreadsheet. The default `ListView.separated` divider, section breaks, and inline groupings inside cards are good places. Decorative-only.

## Specs (M3 defaults)

| Property | Value |
|---|---|
| `color` | `outlineVariant` |
| `space` | 16 (total vertical space — 8 above, 8 below the line) |
| `thickness` | 1 |
| `indent` | 0 |
| `endIndent` | 0 |

`outlineVariant` is the decorative outline role — explicitly *not* required to meet 3:1 contrast. That's intentional: the divider is a visual hint, not a structural boundary.

## States

Dividers don't have states. They're not interactive.

## Variants

| Variant | When |
|---|---|
| **Inset divider** | Aligned with the title in a `ListTile` list — `Divider(indent: 72)` to skip past the leading icon. |
| **Full-bleed divider** | Section break between content blocks. The default. |
| **Subheader divider** | Used together with a `ListTile.dense` subheader to introduce a list section. |

## Accessibility

- Decorative only. Wrap with `ExcludeSemantics` if it's purely visual — assistive tech doesn't need to announce it. (`Divider` already excludes itself in most cases via the framework's defaults.)
- Don't rely on a divider to communicate hierarchy. Use a heading or subheader for that — the divider just reinforces the visual structure.

## In this project

[`dividerTheme` at lib/core/theme/app_theme.dart:223](../../lib/core/theme/app_theme.dart#L223):

```dart
DividerThemeData(color: border, thickness: 1, space: 1)
```

Three differences from M3:

- **Color: `border`** — the project's hairline (`#ebebeb` light / `#2e2e2e` dark). M3 uses `outlineVariant`, which the project sets to the same value. So practically: matches.
- **`space: 1`** instead of M3's 16. The project's divider takes only its own height (1 dp), no surrounding padding. This means the divider is a single-pixel rule with no breathing room — typical inside dense lists, where the parent supplies padding.
- **Thickness 1**: matches M3.

Used in 14 files — most heavily in [`lib/features/drive/components/drive_fab.dart`](../../lib/features/drive/components/drive_fab.dart) (sheet sections), [`lib/features/drive/ui/drive_list_slivers.dart`](../../lib/features/drive/ui/drive_list_slivers.dart) (list separators), and [`lib/widgets/sheet/`](../../lib/widgets/sheet/).

### Conventions

- **Use `Divider()` with no parameters** to inherit theme. The 1 dp space means it slots into existing layouts without re-flowing.
- **For a divider with breathing room**, override per-call: `Divider(height: 16)`. Don't change the theme's space — too many places depend on the 1 dp default.
- **For a vertical divider**, use `VerticalDivider` (separate widget). Theme is independent — set `verticalDivider`'s color via `DividerTheme` only if it should match.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Color | `DividerThemeData.color` | [line 223](../../lib/core/theme/app_theme.dart#L223) |
| Thickness | `DividerThemeData.thickness` | [line 223](../../lib/core/theme/app_theme.dart#L223) |
| Space | `DividerThemeData.space` | [line 223](../../lib/core/theme/app_theme.dart#L223) |
