# FAB (Floating Action Button)

> Source: [Flutter source — `_FABDefaultsM3` in `floating_action_button.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/floating_action_button.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

The FAB represents the single most important create/compose action on a screen — the one that does the same thing every time, no matter what's selected. One per screen. If you have two, one of them belongs in the app bar.

In this app, the FAB launches the create-folder/upload menu in [drive_fab.dart](../../lib/features/drive/components/drive_fab.dart) — exactly the canonical M3 use.

## Anatomy

```
       ┌───────────────────────────┐
       │  [icon]   Label           │   FAB.extended (used here)
       └───────────────────────────┘
       16 dp radius, 56 dp tall
```

Other variants:

```
   ┌──────┐         ┌─────────┐         ┌─────────────┐
   │  ●   │         │    ●    │         │      ●      │
   └──────┘         └─────────┘         │             │
   small 40         regular 56          │             │
                                        └─────────────┘
                                        large 96
```

## Specs (M3 defaults)

| Property | Regular | Small | Large | Extended |
|---|---:|---:|---:|---:|
| Size | 56 × 56 | 40 × 40 | 96 × 96 | min ?, height 56 |
| Corner radius | 16 | 12 | 28 | 16 |
| Icon size | 24 | 24 | 36 | 24 |
| Background | `primaryContainer` | `primaryContainer` | `primaryContainer` | `primaryContainer` |
| Foreground | `onPrimaryContainer` | `onPrimaryContainer` | `onPrimaryContainer` | `onPrimaryContainer` |
| Elevation (resting) | 6 | 6 | 6 | 6 |
| Elevation (focused) | 6 | 6 | 6 | 6 |
| Elevation (hovered) | 8 | 8 | 8 | 8 |
| Elevation (highlight) | 6 | 6 | 6 | 6 |
| Splash color | `onPrimaryContainer @ 0.10` | same | same | same |
| Hover color | `onPrimaryContainer @ 0.08` | same | same | same |
| Focus color | `onPrimaryContainer @ 0.10` | same | same | same |

### Extended FAB only

| Property | Value |
|---|---|
| `extendedTextStyle` | `labelLarge` |
| `extendedIconLabelSpacing` | 8 |
| `extendedPadding` | `start: 16` (with icon) or `20`; `end: 20` |

## Variants

| Variant | When |
|---|---|
| Regular (56) | The default. |
| Small (40) | Compact screens, secondary destinations within a multi-pane layout. |
| Large (96) | Hero placement on a content-light screen — feature discoverability. |
| Extended | When the action's icon alone is ambiguous and a label clarifies. Used here for the drive FAB. |

## Accessibility

- 56 dp regular and 40 dp small both hit the 48 × 48 tap-target floor (the framework inflates the small FAB's hit region via `materialTapTargetSize`).
- Always supply `tooltip` — for icon-only FABs especially. The extended variant's label substitutes, but adding a tooltip too doesn't hurt.
- Hover elevation (8) is a real shadow. If you flatten with `surfaceTintColor: Colors.transparent`, the hover bump still paints unless `hoverElevation: 0` is set explicitly.

## In this project

[`floatingActionButtonTheme` at lib/core/theme/app_theme.dart:318-329](../../lib/core/theme/app_theme.dart#L318-L329):

```dart
backgroundColor: primary,             // diverges: M3 primaryContainer
foregroundColor: onPrimary,           // diverges: M3 onPrimaryContainer
elevation: 0,                         // diverges: M3 = 6
focusElevation: 0,                    // diverges: M3 = 6
hoverElevation: 0,                    // diverges: M3 = 8
highlightElevation: 0,                // diverges: M3 = 6
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadii.pill),  // 100 — pill, diverges: M3 16
),
extendedTextStyle: labelLarge.copyWith(color: onPrimary),  // matches M3 typography
```

Two project decisions:

1. **Primary, not primary container.** In the project's monochrome scheme the difference is academic — primary and primaryContainer would both end up close to the ink/canvas pair. Using `primary` keeps the FAB visually identical to the filled button (both are pill-shaped, both ink-on-canvas), which reinforces "same emphasis level, different placement".
2. **Pill shape, not 16 dp radius.** The project unifies button and FAB shape — every container-with-an-action is a pill. M3's 16 dp radius would visually cluster the FAB with cards (also rounded), which the project explicitly doesn't want.

Used in [`lib/features/drive/components/drive_fab.dart`](../../lib/features/drive/components/drive_fab.dart) — `FloatingActionButton.extended` with the create/upload menu.

### Conventions

- **Use `FloatingActionButton.extended`** in this project. The team has standardized on the labeled variant.
- **Don't change the FAB color per-screen.** It's the brand affordance — consistency outweighs context.

### Gaps

- **No `tooltip` set in the theme.** The widget needs `tooltip:` per-call. Confirm the drive FAB has one.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Background | `FloatingActionButtonThemeData.backgroundColor` | [line 319](../../lib/core/theme/app_theme.dart#L319) |
| Foreground | `FloatingActionButtonThemeData.foregroundColor` | [line 320](../../lib/core/theme/app_theme.dart#L320) |
| Elevation | `elevation` / `focusElevation` / `hoverElevation` / `highlightElevation` | [lines 321-324](../../lib/core/theme/app_theme.dart#L321-L324) |
| Shape | `FloatingActionButtonThemeData.shape` | [line 325](../../lib/core/theme/app_theme.dart#L325) |
| Extended label | `extendedTextStyle` | [line 328](../../lib/core/theme/app_theme.dart#L328) |
