# Dialogs

> Source: [Flutter source — `_DialogDefaultsM3` in `dialog.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/dialog.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

Dialogs interrupt the user with a focused decision. Use them sparingly — they're modal, they block, and they make the rest of the screen unreachable. Reserve for:

- Destructive confirmations ("Delete file?")
- Errors that block continued work
- Inputs the user must complete (renaming, selecting from a small list)

For non-blocking choices, prefer a bottom sheet. For passive notifications, prefer a snackbar.

## Anatomy

```
┌──────────────────────────────────────────────┐
│                                              │
│  [icon]                                      │  optional
│                                              │
│  Title                                       │  headlineSmall
│                                              │
│  Content text or custom body...              │  bodyMedium
│                                              │
│                                              │
│                          Cancel    Confirm   │  TextButton actions
└──────────────────────────────────────────────┘
   28 dp corner, 24 dp padding
```

## Specs (M3 defaults — `_DialogDefaultsM3`)

| Property | Value |
|---|---|
| `backgroundColor` | `surfaceContainerHigh` |
| `surfaceTintColor` | `transparent` |
| `shadowColor` | `transparent` |
| `elevation` | 6 |
| `shape` | `BorderRadius.all(28)` |
| `titleTextStyle` | `headlineSmall` |
| `contentTextStyle` | `bodyMedium` |
| `alignment` | `Alignment.center` |
| `actionsPadding` | `EdgeInsets.only(left: 24, right: 24, bottom: 24)` |
| `iconColor` | `secondary` |
| `clipBehavior` | `Clip.none` |

`AlertDialog` uses these defaults directly (no separate `_AlertDialogDefaultsM3` class).

### `AlertDialog`-specific padding (computed inline)

| Section | Padding |
|---|---|
| Icon | `EdgeInsets.fromLTRB(24, 24, 24, bottom)` where `bottom` = 16 if a title follows, 0 if only content follows, else 24 |
| Title | follows the icon |
| Content | sits between title and actions |
| Actions | `EdgeInsets.only(left: 24, right: 24, bottom: 24)` |

### Fullscreen dialogs

`_DialogFullscreenDefaultsM3` only overrides `backgroundColor` to `surface`. Everything else falls through.

## States

The dialog itself has no states — its actions do (each is a `TextButton`, see [buttons.md](buttons.md)). The scrim behind a dialog uses `ModalBarrierColor`, default `Colors.black54`.

## Variants

| Variant | When |
|---|---|
| **Basic dialog** (`AlertDialog`) | Single, focused decision. Up to two actions. |
| **Dialog with hero icon** | Same as basic but lead with a 24 dp icon to reinforce category (e.g., warning, info). |
| **Fullscreen dialog** (`Dialog.fullscreen`) | Multi-step input or content that needs the whole screen — picker views, account selection. Treated like a modal route, with its own app bar. |

## Accessibility

- Title style is `headlineSmall` (24 / 32 / w400). Don't override unless you have a reason — it's the right balance between authority and not-shouting.
- Dialogs are routed via Flutter's modal system, so they trap focus and announce as modal to assistive tech.
- Actions should be in a sensible reading order — destructive actions on the right, dismiss on the left, in left-to-right locales. Don't reverse this for visual reasons.
- Don't put long content in a basic dialog. If the user has to scroll inside the dialog, use a fullscreen dialog or a sheet.

## In this project

[`dialogTheme` at lib/core/theme/app_theme.dart:330-338](../../lib/core/theme/app_theme.dart#L330-L338):

```dart
backgroundColor: surface,            // diverges: M3 surfaceContainerHigh
surfaceTintColor: Colors.transparent,// matches M3
elevation: 0,                        // diverges: M3 = 6
shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(AppRadii.xl),  // 24 dp — diverges from M3 28
  side: BorderSide(color: border, alpha: 0.78-0.9),  // adds an outline; M3 has none
),
```

The project's dialog is flatter than M3 (no shadow), slightly smaller-cornered (24 vs 28), and outlined — mirroring the card treatment. The visual model is "dialog = card with a scrim", which works because the project doesn't use surface tint at all.

Used in [`lib/features/drive/components/drive_dialogs.dart`](../../lib/features/drive/components/drive_dialogs.dart) — rename, delete, conflict resolution.

### Conventions

- **Reach for `AlertDialog` first.** It picks up the theme automatically. Custom `Dialog` subclasses bypass `dialogTheme` for things they don't proxy (color, elevation are picked up; shape isn't always).
- **Two actions max.** If you have three, your dialog probably wants to be a sheet.
- **Title in `titleLarge` is fine** — the project's `titleLarge` is 20 / w600, close to M3 `headlineSmall`. Don't reach for `displaySmall` or `headlineMedium` for a dialog title.

### Gaps

- **No `iconColor` set.** If a dialog uses the optional icon, it'll fall back to M3's `secondary` (which the project sets to `surfaceSubtle`, an off-white). Either set `iconColor: AppColors.link` in the theme or pass an explicit color per-dialog.
- **`titleTextStyle` and `contentTextStyle` not set.** Dialogs render with `headlineSmall` and `bodyMedium` — but the project's `bodyMedium` defaults to muted color, so dialog body text will be muted. That's surprising. Either override per-dialog with `Text(..., style: textTheme.bodyMedium?.copyWith(color: text))` or set `contentTextStyle` in `dialogTheme`.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Surface color | `DialogThemeData.backgroundColor` | [line 331](../../lib/core/theme/app_theme.dart#L331) |
| Corner | `DialogThemeData.shape` | [line 334](../../lib/core/theme/app_theme.dart#L334) |
| Elevation | `DialogThemeData.elevation` | [line 333](../../lib/core/theme/app_theme.dart#L333) |
| Title style | `DialogThemeData.titleTextStyle` | not set — defaults to `headlineSmall` |
| Body style | `DialogThemeData.contentTextStyle` | not set — defaults to `bodyMedium` (muted) |
| Icon color | `DialogThemeData.iconColor` | not set — defaults to M3 `secondary` |
| Actions padding | `DialogThemeData.actionsPadding` | not set — M3 default |
