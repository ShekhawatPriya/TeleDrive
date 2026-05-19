# Interaction states

> Source: M3 state model + Flutter's `WidgetState` enum and per-component `_*DefaultsM3` overlay maps.

## Purpose

Every interactive surface in M3 has a small set of states it can be in. The framework draws each state with a consistent treatment — a state-layer color over the base, a border thickening, an opacity reduction. The point is: a user looking at the same component on different screens should be able to tell at a glance whether it's tappable, focused, or busy.

## The states

| State | When | Visual cue |
|---|---|---|
| **Enabled** | Default. Interactive and ready. | Component's resting appearance. |
| **Disabled** | Non-interactive (no `onPressed`, or guard condition not met). | Foreground at `0.38` opacity, background at `0.12` opacity. |
| **Hovered** | Mouse pointer over the component (desktop/web). | State-layer overlay at `0.08`. |
| **Focused** | Keyboard focus (Tab key). | State-layer overlay at `0.10`, sometimes a border thickening. |
| **Pressed** | Mouse/finger down on the component. | State-layer overlay at `0.10` plus ripple. |
| **Dragged** | Component is being dragged. | State-layer overlay at `0.16`. |
| **Selected** | Toggled on (Checkbox, Switch, Radio, ListTile selected). | Color shift to `primary`/`onPrimary`; for tiles, optional `selectedTileColor`. |
| **Error** | In an error state (TextField with `errorText`, Checkbox with `errorText`). | Border/foreground shifts to `error`. |

## Combination rules

States can co-occur. Most common combinations:

- **Focused + hovered** — desktop, mouse hovering over a focused control. Focused visual takes priority on text fields (2 dp border), hovered on most others.
- **Selected + hovered** — the user is hovering over an already-selected item. State layer uses the selected role's "on" color.
- **Pressed + selected** — tapping a selected item to deselect.
- **Error + focused** — focused on an invalid input. Border becomes `error` at 2 dp, label becomes `error`.
- **Disabled + selected** — a selected-but-frozen state (e.g., read-only checkbox). Component takes the disabled treatment but retains the selected mark.

## Priority on text fields

Text fields invert the usual priority (per Flutter source comment in `_InputDecoratorDefaultsM3`):

> "For InputDecorator, focused state takes precedence over hovered state."

Reason: on desktop a field is usually both focused and hovered at once. The 2 dp focused border is the primary cue; the hover treatment is secondary.

For other components (buttons, tiles, cards), hovered usually takes precedence — hover is mainly used to determine the overlay color, and focused is signaled by a separate ring.

## Flutter implementation

Flutter exposes states via `WidgetState` (formerly `MaterialState`):

```dart
enum WidgetState {
  hovered, focused, pressed, dragged,
  selected, scrolledUnder, disabled, error,
}
```

Components that respect states accept `WidgetStateProperty<T>` for color, border, text style, etc. Resolve in priority order:

```dart
overlayColor: WidgetStateProperty.resolveWith((states) {
  if (states.contains(WidgetState.disabled)) return null;
  if (states.contains(WidgetState.error)) return errorColor.withOpacity(0.10);
  if (states.contains(WidgetState.dragged)) return primary.withOpacity(0.16);
  if (states.contains(WidgetState.pressed)) return primary.withOpacity(0.10);
  if (states.contains(WidgetState.focused)) return primary.withOpacity(0.10);
  if (states.contains(WidgetState.hovered)) return primary.withOpacity(0.08);
  return null;
});
```

The `disabled` check first is important — most disabled components shouldn't paint a state layer (they're not interactive).

## State-by-component summary

| Component | Disabled | Hovered | Focused | Pressed | Dragged |
|---|---|---|---|---|---|
| FilledButton | bg `onSurface@0.12`, fg `onSurface@0.38` | `onPrimary@0.08`, elev 1 | `onPrimary@0.10` | `onPrimary@0.10` | — |
| Card (with InkWell) | — | `onSurface@0.08` | `onSurface@0.10` | `onSurface@0.10` | — |
| Checkbox unselected | border `onSurface@0.38` | border `onSurface`; overlay `onSurface@0.08` | overlay `onSurface@0.10` | overlay `primary@0.10` | — |
| Checkbox selected | fill `onSurface@0.38` | overlay `primary@0.08` | overlay `primary@0.10` | overlay `onSurface@0.10` | — |
| TextField (filled) | fill `onSurface@0.04`, border `onSurface@0.38` | border `onSurface` | border `primary` 2dp | (focused dominates) | — |
| ListTile | text `theme.disabledColor` | overlay `onSurface@0.08` | overlay `onSurface@0.10` | overlay `onSurface@0.10` | — |
| Switch / Slider | — | — | — | — | overlay `primary@0.16` |

## Focus indicators

Focus is the most-overlooked state. A keyboard-only user navigates entirely by focus.

- **Don't disable focus by setting `focusColor: Colors.transparent`** unless you've replaced it with a visible alternative.
- **For custom widgets, use `FocusableActionDetector`** — it gives you explicit `onShowFocusHighlight` callbacks and ensures keyboard focus is announced to AT.
- **The 2 dp focused border on text fields is the canonical pattern.** Any custom-painted input should match: a clear, visible boundary that distinguishes "focused" from "hovered" without requiring color perception.

## Project state

The project doesn't define `overlayColor` in any of its theme entries. State layers come from the M3 defaults. Implications:

- **Cards aren't tappable by default** — the project's outlined card has no `InkWell`. Tappable cards must wrap their child in one. When they do, M3 state layers paint correctly.
- **Filled buttons get `onPrimary@0.08` on hover.** With `surfaceTintColor: transparent` set globally, the hover *tint* doesn't paint, but the hover *state layer* still does. Visible on desktop/web.
- **Focused text-field borders are 1.2 dp not 2 dp** (project override at [line 241](../../lib/core/theme/app_theme.dart#L241)). Focus is still signaled — just slightly subtler than M3 default.

## Checklist for new components

When adding a new interactive widget, verify each state:

- [ ] Disabled: foreground reduced to ~0.38, background to ~0.12, no state layers paint.
- [ ] Hovered (desktop): visible state layer at ~0.08 over the foreground role.
- [ ] Focused (keyboard): visible focus ring or state layer at ~0.10. Distinct from hover.
- [ ] Pressed: ripple plus state layer at ~0.10. Brief, then settles.
- [ ] Dragged (if applicable): state layer at ~0.16.
- [ ] Selected (if applicable): primary-toned shift, persistent.
- [ ] Error (if applicable): error-toned shift, persistent.

If any of those is missing, the component is a worse keyboard / desktop / a11y citizen than its M3 peers.
