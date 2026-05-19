# Snackbar

> Source: [Flutter source — `_SnackbarDefaultsM3` in `snack_bar.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/snack_bar.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

A snackbar is the lightest-weight feedback channel: a brief message, optionally a single action, auto-dismissing. Use for confirmation of an action that has already happened ("Link copied", "Folder created") and short error messages that don't block the user. Snackbars are *informational* — they're not for asking questions or guarding destructive operations.

## Anatomy

```
┌────────────────────────────────────────────────┐
│  Message text                          ACTION  │
└────────────────────────────────────────────────┘
   bodyMedium / onInverseSurface          inversePrimary
```

## Specs (M3 defaults)

| Property | Value |
|---|---|
| `backgroundColor` | `inverseSurface` |
| `actionTextColor` | `inversePrimary` (all states) |
| `disabledActionTextColor` | `inversePrimary` |
| `contentTextStyle` | `bodyMedium` colored `onInverseSurface` |
| `elevation` | 6 |
| `shape` | `BorderRadius.all(4)` |
| `behavior` | `SnackBarBehavior.fixed` |
| `insetPadding` | `EdgeInsets.fromLTRB(15, 5, 15, 10)` |
| `actionOverflowThreshold` | 0.25 |
| `showCloseIcon` | `false` |
| `closeIconColor` | `onInverseSurface` |

The 4 dp radius and the inverse-surface color combination are the M3 signature. The sharp corners distinguish a snackbar from a card (12 dp), a sheet (28 dp), or a dialog (28 dp).

## Behaviors

| `SnackBarBehavior` | When |
|---|---|
| `fixed` (M3 default) | Pinned to the bottom edge, full bleed. Use when the snackbar shouldn't compete with floating UI. |
| `floating` | Detached, floats above the bottom edge. Use when there's a FAB or bottom nav — the framework offsets above them. |

## Duration

Defaults to 4 seconds. Increase for messages with an action (gives the user time to tap). Decrease only for trivial confirmations. M3 caps actionable snackbars at ~10 seconds — beyond that, the user has already moved on.

## Accessibility

- Snackbars are announced via the `Liveregion` semantic. They interrupt assistive tech, so don't fire them for non-actionable noise (route changes, debounced state).
- The inverse-surface palette is intentional — the snackbar should read as "different surface, same app", not as a foreign element.
- Action text uses `inversePrimary`; in this project's monochrome scheme, that means the action label uses the project's primary color reversed. Verify contrast: `inversePrimary` on `inverseSurface` should clear 4.5:1 for normal text.
- Show only one snackbar at a time — the framework queues them automatically.

## In this project

[`snackBarTheme` at lib/core/theme/app_theme.dart:352-362](../../lib/core/theme/app_theme.dart#L352-L362):

```dart
backgroundColor: dark ? AppColors.canvas : AppColors.ink,  // matches M3 inverse intent
contentTextStyle: bodySmall.copyWith(color: ink/canvas),   // diverges: M3 uses bodyMedium
behavior: SnackBarBehavior.floating,                       // diverges: M3 fixed
elevation: 0,                                              // diverges: M3 = 6
shape: BorderRadius.circular(AppRadii.lg),                 // 20 dp — diverges from M3 4dp
```

The project's snackbar is **floating, flat, and round** — the opposite of M3's pinned, elevated, square treatment. This matches the broader project aesthetic (no shadows, generous radii, content-forward).

Used widely (25+ files):
- [`lib/features/share/ui/create_share_sheet.dart`](../../lib/features/share/ui/create_share_sheet.dart)
- [`lib/features/drive/`](../../lib/features/drive/) — copy, move, delete confirmations
- [`lib/features/upload/`](../../lib/features/upload/) — upload completion
- And many more

### Conventions

- **One sentence.** If you need two, the message belongs in a dialog.
- **Inline action only when reversible.** "Item deleted — UNDO" is correct. "Couldn't connect — RETRY" is correct. "Saved" with no action is correct.
- **Don't surface technical errors.** "Network error: ECONNREFUSED" should become "Couldn't connect — try again".

### Gaps

- **`actionTextColor` not set.** Falls back to M3 `inversePrimary`. The project sets `inversePrimary` to `canvas`/`ink` — same as the foreground. Action labels are visually indistinguishable from message text. Set `actionTextColor: AppColors.link` (or an inverse equivalent) in the theme.
- **`contentTextStyle` uses `bodySmall`** (12 sp) — smaller than M3's `bodyMedium` (14 sp). Fine for a content-dense app, but verify legibility on outdoor-light tablet use.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Surface color | `SnackBarThemeData.backgroundColor` | [line 353](../../lib/core/theme/app_theme.dart#L353) |
| Message style | `SnackBarThemeData.contentTextStyle` | [line 354](../../lib/core/theme/app_theme.dart#L354) |
| Behavior | `SnackBarThemeData.behavior` | [line 357](../../lib/core/theme/app_theme.dart#L357) |
| Elevation | `SnackBarThemeData.elevation` | [line 358](../../lib/core/theme/app_theme.dart#L358) |
| Shape | `SnackBarThemeData.shape` | [line 359](../../lib/core/theme/app_theme.dart#L359) |
| Action color | `SnackBarThemeData.actionTextColor` | not set — defaults to `inversePrimary` |
