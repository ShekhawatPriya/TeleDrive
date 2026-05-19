# Checkbox

> Source: [Flutter source — `_CheckboxDefaultsM3` in `checkbox.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/checkbox.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

A checkbox is a binary control for a single item ("agree to terms", "include in selection"). For toggling a setting, prefer a `Switch`. For one-of-many, prefer a `Radio`.

## Specs (M3 defaults)

| Property | Value |
|---|---|
| `shape` | `RoundedRectangleBorder(BorderRadius.all(Radius.circular(2)))` — 2 dp |
| `splashRadius` | 20 (`40 / 2`) |
| `materialTapTargetSize` | inherits `theme.materialTapTargetSize` |
| `visualDensity` | `VisualDensity.standard` |

### Fill color (per state)

| State | Fill |
|---|---|
| Selected, enabled | `primary` |
| Selected, error | `error` |
| Selected, disabled | `onSurface @ 0.38` |
| Unselected, enabled | `transparent` |
| Unselected, disabled | `transparent` |

### Check (tick) color

| State | Color |
|---|---|
| Selected, enabled | `onPrimary` |
| Selected, error | `onError` |
| Selected, disabled | `surface` |
| Unselected (any) | `transparent` |

### Border (`side`)

| State | Width | Color |
|---|---:|---|
| Default (unselected, enabled) | 2 | `onSurfaceVariant` |
| Hovered | 2 | `onSurface` |
| Focused | 2 | `onSurface` |
| Pressed | 2 | `onSurface` |
| Error | 2 | `error` |
| Disabled, unselected | 2 | `onSurface @ 0.38` |
| Selected | 0 | `transparent` (fill takes over) |
| Disabled, selected | 2 | `transparent` |

### Overlay (state layer) — drawn under the splash radius

| State | Color |
|---|---|
| Pressed, unselected | `primary @ 0.10` |
| Pressed, selected | `onSurface @ 0.10` |
| Pressed, error | `error @ 0.10` |
| Hovered, unselected | `onSurface @ 0.08` |
| Hovered, selected | `primary @ 0.08` |
| Hovered, error | `error @ 0.08` |
| Focused, unselected | `onSurface @ 0.10` |
| Focused, selected | `primary @ 0.10` |
| Focused, error | `error @ 0.10` |

## Tristate

Set `tristate: true` to allow `null` (mixed/indeterminate) in addition to true/false. Common in "select all" patterns where some children are checked.

## Accessibility

- The splash radius (20) gives a 40 dp interactive area; with `materialTapTargetSize: padded` (default), the framework expands the hit region to 48 × 48.
- Errors must be communicated via more than color. Pair an error checkbox with `errorText` below or `Semantics(label: 'error: ...')`.
- For tristate checkboxes, ensure assistive tech reads the indeterminate state — Flutter's `Checkbox` does this automatically, but custom-painted checkboxes need to set `Semantics(checked: ..., mixed: ...)`.

## In this project

No `checkboxTheme` is set in [app_theme.dart](../../lib/core/theme/app_theme.dart) — checkboxes use full M3 defaults. That means:

- Selected fill = `primary` = `AppColors.ink` / `AppColors.canvas` (project ink-on-canvas).
- Unselected border = `onSurfaceVariant` = `AppColors.mute`.
- Error state = `AppColors.error` (#ee0000).

Used in:
- [`lib/features/photos/ui/file_viewer_screen.dart`](../../lib/features/photos/ui/file_viewer_screen.dart)
- [`lib/features/auth/ui/login_screen.dart`](../../lib/features/auth/ui/login_screen.dart) — terms acceptance
- [`lib/features/upload/ui/components/upload_card.dart`](../../lib/features/upload/ui/components/upload_card.dart)
- [`lib/features/upload/ui/components/upload_thumb_slot.dart`](../../lib/features/upload/ui/components/upload_thumb_slot.dart)

### Conventions

- **Wrap in a `CheckboxListTile`** when the label is descriptive. It handles target sizing and label/control alignment.
- **Bare `Checkbox` is fine** when it's adjacent to a small label or in a multi-select list (the `ListTile` itself is the tap target).

### Gaps

- **No project theme.** If the project's accent color ever diverges from `primary` (e.g., link-blue for accents instead of ink), checkboxes will still use ink. Either add a `checkboxTheme` or accept the visual hierarchy.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Selected fill | `Checkbox.fillColor` (`WidgetStateProperty`) | not themed — defaults to `primary` |
| Tick color | `Checkbox.checkColor` | not themed — defaults to `onPrimary` |
| Border | `Checkbox.side` | not themed — defaults to `onSurfaceVariant` 2dp |
| Shape | `Checkbox.shape` | not themed — defaults to 2 dp radius |
| State layers | `Checkbox.overlayColor` | not themed — defaults per state map above |
