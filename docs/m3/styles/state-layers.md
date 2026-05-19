# State layers

> Source: opacity values pulled from `_FilledButtonDefaultsM3`, `_FABDefaultsM3`, `_CheckboxDefaultsM3` overlay maps. M3 uses a consistent set of state-layer opacities across all components.

## Purpose

A state layer is a thin tinted overlay drawn on top of an interactive surface to indicate it's being interacted with — hovered, focused, pressed, or dragged. The color comes from the foreground role (so it has guaranteed contrast against the background) at a specific opacity.

State layers are how M3 communicates interaction without changing the component's color or shape. The button stays `primary`; the hover state is `onPrimary @ 0.08` painted over it.

## M3 state-layer opacities

| State | Opacity |
|---|---:|
| Hovered | 0.08 |
| Focused | 0.10 |
| Pressed | 0.10 |
| Dragged | 0.16 |

These values appear consistently across the M3 defaults classes:

- `_FilledButtonDefaultsM3.overlayColor` → `onPrimary @ 0.08 / 0.10 / 0.10`
- `_FABDefaultsM3` → `onPrimaryContainer @ 0.08 / 0.10 / 0.10`
- `_CheckboxDefaultsM3.overlayColor` → see [components/checkbox.md](../components/checkbox.md) state map (uses 0.08 / 0.10 / 0.10 over `primary` or `onSurface` depending on selection state)
- Filled button source comments confirm pressed and focused both use 0.10, hovered 0.08.

The 0.16 dragged value is for components with drag affordances (slider thumb, switch thumb, FAB drag).

## Color choice

The state-layer color is the **foreground** role, not the surface role:

| Component | Surface role | State-layer color |
|---|---|---|
| FilledButton | `primary` | `onPrimary` |
| FilledTonalButton | `secondaryContainer` | `onSecondaryContainer` |
| OutlinedButton | transparent | `onSurface` (or `primary` if branded) |
| Card (with InkWell) | `surface` / `surfaceContainerLow` | `onSurface` |
| ListTile | transparent (`tileColor`) | `onSurface` |
| Checkbox unselected | transparent | `onSurface` (or `primary` when selected, `error` in error state) |

Why the foreground? Because that's the color guaranteed to have ≥ 4.5:1 contrast against the surface — painting it at low opacity is a guaranteed-perceivable cue.

## How Flutter applies state layers

Flutter resolves overlay colors via `WidgetStateProperty<Color?>` keyed on `WidgetState`:

```dart
overlayColor: WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.pressed)) return onPrimary.withOpacity(0.10);
  if (states.contains(WidgetState.hovered)) return onPrimary.withOpacity(0.08);
  if (states.contains(WidgetState.focused)) return onPrimary.withOpacity(0.10);
  return null;
})
```

The `Material` widget paints this overlay *between* the surface (color) and its child. State layers and ripples coexist — the ripple is a transient circle that grows out from the tap point; the state layer is a persistent tint that stays while the state is active.

## Project state

The project doesn't define `overlayColor` in any of its theme files (`filledButtonTheme`, `floatingActionButtonTheme`, etc.). That means:

- **Buttons inherit M3 default state layers.** Hover and pressed states paint `onPrimary @ 0.08–0.10` — visible on web/desktop, mostly invisible on touch (since hover doesn't apply).
- **Checkboxes inherit M3 default state layers.** The expected `onSurface @ 0.08` hover is applied.
- **Cards and `ListTile` need explicit `InkWell` to get state layers.** Wrapping a tappable card in `InkResponse(splashColor: ..., highlightColor: ...)` gives manual control.

## Recommendation: align dragged opacity

For a project that adds drag interactions (reorderable lists, drag-to-upload):

```dart
// In FilledButtonThemeData / others that need draggable variants
overlayColor: WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.dragged)) return onPrimary.withOpacity(0.16);
  if (states.contains(WidgetState.pressed))  return onPrimary.withOpacity(0.10);
  if (states.contains(WidgetState.focused))  return onPrimary.withOpacity(0.10);
  if (states.contains(WidgetState.hovered))  return onPrimary.withOpacity(0.08);
  return null;
}),
```

For consistency, define a small helper:

```dart
class StateOverlay {
  static const hovered = 0.08;
  static const focused = 0.10;
  static const pressed = 0.10;
  static const dragged = 0.16;

  static WidgetStateProperty<Color?> resolveOver(Color color) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.dragged)) return color.withOpacity(dragged);
      if (states.contains(WidgetState.pressed)) return color.withOpacity(pressed);
      if (states.contains(WidgetState.focused)) return color.withOpacity(focused);
      if (states.contains(WidgetState.hovered)) return color.withOpacity(hovered);
      return null;
    });
  }
}
```

This is a follow-up task — not part of these docs.

## Accessibility note

State layers are a *secondary* affordance. They make a hover/press feel responsive but they're not what tells the user a button is interactive — that's the button's typography, color, and shape. Don't lean on the state layer alone:

- A checkbox without a clear label isn't accessible just because it has a hover state.
- A custom InkWell with a state layer only on hover is invisible to keyboard users — also handle `focused`.

## Token gap (flagged for follow-up)

- Define the `StateOverlay` helper (or equivalent) and use it in component themes.
- Audit custom `InkWell` / `InkResponse` calls — make sure they pass `splashColor` and `highlightColor` from the right roles.
- Verify the dark-mode state-layer is perceivable. `onPrimary @ 0.08` over a near-black `primary` is darker than the same over a white primary; on dark surfaces the contrast can vanish.
