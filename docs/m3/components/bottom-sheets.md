# Bottom sheets

> Source: [Flutter source — `_BottomSheetDefaultsM3` in `bottom_sheet.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/bottom_sheet.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

Bottom sheets reveal supplementary content from the bottom of the screen — pickers, action menus, secondary tasks. M3 has two flavors:

- **Modal** — blocks the rest of the UI behind a scrim. Use for tasks that must be completed or dismissed before continuing (sharing, uploading, confirming a destructive action).
- **Standard** — non-modal companion content; the user can interact with the rest of the screen. Rare on mobile, more common on tablet.

## Anatomy

```
┌────────────────────────────────────────┐
│              ▭ drag handle             │  32 × 4, top
├────────────────────────────────────────┤
│   Header: title + optional subtitle    │
│                                        │
│   Body: actions, list, form, etc.      │
│                                        │
└────────────────────────────────────────┘
   Top corners: 28 dp; bottom corners: 0
   Max width: 640 dp (centered on tablet)
```

## Specs (M3 defaults)

| Property | Value |
|---|---|
| `backgroundColor` | `surfaceContainerLow` |
| `modalBackgroundColor` | falls back to `backgroundColor` |
| `surfaceTintColor` | `transparent` |
| `shadowColor` | `transparent` |
| `elevation` | 1 |
| `modalElevation` | 1 |
| `shape` | `BorderRadius.vertical(top: Radius.circular(28))` |
| `constraints.maxWidth` | 640 |
| `dragHandleSize` | `Size(32, 4)` |
| `dragHandleColor` | `onSurfaceVariant` (per code) — doc comment says `onSurfaceVariant @ 0.4` |
| `modalBarrierColor` | not in defaults class; falls back to `Colors.black54` |

The 28 dp top radius and the 32 × 4 drag handle are the two shape signatures of an M3 sheet — get those right and the sheet reads as M3 even with custom internals.

## States and behavior

`showModalBottomSheet` configuration that matters:

| Param | Default | Notes |
|---|---|---|
| `isScrollControlled` | `false` | Set `true` when the sheet contains a scrolling area or a keyboard-aware form, otherwise the sheet is capped at ~50% of the screen. |
| `isDismissible` | `true` | Tap outside to dismiss. Set `false` for tasks that need explicit confirmation. |
| `enableDrag` | `true` | Drag down to dismiss. |
| `useSafeArea` | `false` | Set `true` to respect notches and the bottom system bar. |
| `showDragHandle` | `false` | Set `true` for the M3 drag handle. The project uses a custom one — see below. |

## Variants

| Variant | When |
|---|---|
| Modal — short | A list of 3-7 actions (share menu, file actions). Sized to content. |
| Modal — full | A form or workflow that needs vertical space. Use `DraggableScrollableSheet` for adjustable height. |
| Standard | Side panel on tablet/desktop. Not used on mobile. |

## Accessibility

- Drag handle is decorative — don't make it the only affordance for dismiss. The framework provides keyboard `Esc` and the dismiss button on assistive tech.
- The 28 dp top radius doesn't affect tap targets — the full sheet body is reachable.
- When `isScrollControlled: true`, ensure the sheet's internal `ScrollView` is reachable via assistive tech (don't gate it behind a `Listener` that swallows events).
- Modal sheets must not exceed the viewport — combine `useSafeArea: true` with `DraggableScrollableSheet(maxChildSize: 0.92)` for a comfortable cap.

## In this project

[`bottomSheetTheme` at lib/core/theme/app_theme.dart:339-351](../../lib/core/theme/app_theme.dart#L339-L351):

```dart
backgroundColor: surface,                    // diverges: M3 surfaceContainerLow
modalBackgroundColor: surface,               // same
surfaceTintColor: Colors.transparent,        // matches M3
elevation: 0,                                // diverges: M3 = 1
modalElevation: 0,                           // diverges: M3 = 1
shape: BorderRadius.vertical(
  top: Radius.circular(AppRadii.sheet),      // 28 dp — matches M3 exactly
),
clipBehavior: Clip.antiAlias,                // diverges: M3 Clip.none
```

The 28 dp radius is preserved exactly (`AppRadii.sheet = 28`) — that's the one M3 measurement the project keeps. Everything else flattens (elevation 0, no shadow, no surface tint).

### Custom sheet primitives

The project has its own sheet vocabulary in [`lib/widgets/sheet/`](../../lib/widgets/sheet/):

| Widget | Role |
|---|---|
| `SheetDragHandle` | The 32 × 4 indicator at the top. Uses muted color. Replaces M3 `showDragHandle: true` so the project controls placement and color. |
| `SheetHeader` | Title/subtitle row, optional leading icon container, optional trailing widget. Sits below the drag handle. |
| `SheetActionTile` | Icon + label + optional subtitle, with a `destructive` variant for delete-style actions. |

These are the building blocks. Most sheets in the app are: `SheetDragHandle` → `SheetHeader` → list of `SheetActionTile` or a custom body.

Used in:
- [`lib/features/drive/components/drive_action_sheet.dart`](../../lib/features/drive/components/drive_action_sheet.dart) — file/folder actions menu
- [`lib/features/drive/components/drive_fab.dart`](../../lib/features/drive/components/drive_fab.dart) — create menu
- [`lib/features/upload/ui/upload_sheet.dart`](../../lib/features/upload/ui/upload_sheet.dart) — upload progress sheet (uses `DraggableScrollableSheet`)
- [`lib/features/share/ui/create_share_sheet.dart`](../../lib/features/share/ui/create_share_sheet.dart)

### Conventions to follow

- **Compose with the primitives.** Don't reach for `showDragHandle: true` — use `SheetDragHandle` so future styling changes happen in one place.
- **For scrolling content, use `DraggableScrollableSheet`** with `isScrollControlled: true` on the `showModalBottomSheet` call. The upload sheet is the reference pattern.
- **For destructive confirmations, prefer a dialog.** Bottom sheets are dismissible by drag — accidentally swiping away a confirmation isn't great UX.

### Gaps

- **No drag handle theming via `BottomSheetThemeData.dragHandleColor` / `dragHandleSize`.** The project uses `SheetDragHandle` instead, which is fine, but it means setting `showDragHandle: true` on `showModalBottomSheet` would render an unstyled M3 handle. Either don't pass that flag, or wire those theme fields too.
- **`modalBarrierColor` not customized.** Defaults to `Colors.black54`. If the project's dark mode wants a different scrim density, set it via `showModalBottomSheet(barrierColor: ...)` or via the route.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Container color | `BottomSheetThemeData.backgroundColor` | [line 340](../../lib/core/theme/app_theme.dart#L340) |
| Modal container | `BottomSheetThemeData.modalBackgroundColor` | [line 341](../../lib/core/theme/app_theme.dart#L341) |
| Top corner | `BottomSheetThemeData.shape` | [line 345](../../lib/core/theme/app_theme.dart#L345) |
| Drag handle | (custom) `SheetDragHandle` | [lib/widgets/sheet/](../../lib/widgets/sheet/) |
| Scroll behavior | `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet` | call sites |
