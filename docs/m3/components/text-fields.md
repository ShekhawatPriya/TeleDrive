# Text fields

> Source: [Flutter source — `_InputDecoratorDefaultsM3` in `input_decorator.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/input_decorator.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

Text fields collect freeform input. M3 has two variants — **filled** (default) and **outlined**. Pick filled when the field sits on a plain surface and you want it visually anchored; pick outlined when you have multiple fields stacked together (the outlines give clear separation without piling up tonal noise).

## Anatomy

```
┌──────────────────────────────────────────┐
│  Label (floats up when focused/filled)   │
│  ┌────────────────────────────────────┐  │
│  │  [icon]  Input text       [icon]   │  │
│  └────────────────────────────────────┘  │  outline (or active indicator for filled)
│  Helper / error text                     │  bodySmall
└──────────────────────────────────────────┘
```

## Specs (M3 defaults)

| Property | Value |
|---|---|
| Label / floating label | `bodyLarge` |
| Helper text | `bodySmall` colored `onSurfaceVariant` |
| Error text | `bodySmall` colored `error` |
| Input text | inherits the field's `style` (typically `bodyLarge`) |
| Icon | 24 dp; color `onSurfaceVariant` |

### Content padding (set by build, not the defaults class)

| Variant + density | Padding |
|---|---|
| Filled, non-dense | `EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8)` |
| Filled, dense | `(12, 4, 12, 4)` |
| Non-filled, non-outline | `(0, 8, 0, 8)` |
| Non-filled, dense | `(0, 4, 0, 4)` |
| Outlined, non-dense | `(12, 20, 12, 12)` |
| Outlined, dense | `(12, 16, 12, 8)` |

## State map

### Filled — fill color

| State | Fill |
|---|---|
| Enabled | `surfaceContainerHighest` |
| Disabled | `onSurface @ 0.04` |

### Filled — active indicator (bottom border)

| State | Border |
|---|---|
| Enabled | `onSurfaceVariant`, 1 |
| Hovered | `onSurface`, 1 |
| Focused | `primary`, **2** |
| Error | `error`, 1 |
| Error + hovered | `onErrorContainer`, 1 |
| Error + focused | `error`, **2** |
| Disabled | `onSurface @ 0.38`, 1 |

### Outlined — border

| State | Border |
|---|---|
| Enabled | `outline`, 1 |
| Hovered | `onSurface`, 1 |
| Focused | `primary`, **2** |
| Error | `error`, 1 |
| Error + hovered | `onErrorContainer`, 1 |
| Error + focused | `error`, **2** |
| Disabled | `onSurface @ 0.12`, 1 |

### Label / floating label color (per state)

| State | Color |
|---|---|
| Enabled | `onSurfaceVariant` |
| Hovered | `onSurfaceVariant` |
| Focused | `primary` |
| Error / error+hovered / error+focused | `error` (or `onErrorContainer` when hovered) |
| Disabled | `onSurface @ 0.38` |

### Suffix icon

| State | Color |
|---|---|
| Enabled / focused / hovered | `onSurfaceVariant` |
| Error | `error` |
| Error + hovered | `onErrorContainer` |
| Disabled | `onSurface @ 0.38` |

### Hint

`onSurfaceVariant` enabled, `onSurface @ 0.38` disabled.

### Behavior note from source

> "For InputDecorator, focused state takes precedence over hovered." That's the opposite of most other components. The 2 dp focused border outranks the hover treatment because keyboard focus and mouse hover commonly co-occur on desktop.

## Variants

| Variant | When |
|---|---|
| **Filled** (M3 default) | Single field on a plain surface, or any field that should look "tappable" without the user thinking. |
| **Outlined** | Forms with multiple fields, dense screens, fields inside cards. The outline gives separation that doesn't compete with surface coloring. |

`InputDecoration.filled: true` selects filled with the active-indicator border. Setting `border: OutlineInputBorder(...)` selects outlined.

## Accessibility

- Floating label is the WCAG-compliant pattern (label is always visible at some position, not just inside the field as a placeholder). Don't replace it with hint-only.
- Error text must be programmatically associated — `errorText` on `InputDecoration` does this automatically.
- The 2 dp focused border is also the keyboard-focus indicator. Don't override without providing an alternative focus ring.
- Icon-only buttons inside a field (e.g., clear, show/hide password) need 48 × 48 tap targets. Wrap them in `IconButton` (which already meets this) rather than a bare `GestureDetector` on a 24 dp `Icon`.

## In this project

[`inputDecorationTheme` at lib/core/theme/app_theme.dart:224-249](../../lib/core/theme/app_theme.dart#L224-L249):

```dart
filled: true,                                       // matches M3
fillColor: surface,                                 // diverges: M3 surfaceContainerHighest
hintStyle: bodyMedium.copyWith(color: muted),       // bodySmall closer to M3
labelStyle: bodyMedium.copyWith(color: muted),      // diverges: M3 bodyLarge
prefixIconColor / suffixIconColor: muted,           // matches M3 onSurfaceVariant
contentPadding: horizontal: 16, vertical: 15,       // diverges: M3 (12,8,12,8)
border: OutlineInputBorder(radius: AppRadii.md),    // 16 dp — diverges: M3 has no input radius standard, but typical is 4 dp on filled
focusedBorder: BorderSide(color: primary, width: 1.2),  // diverges: M3 = 2 dp
errorBorder: BorderSide(color: error, width: 1),    // matches M3
```

The project uses **outlined fields with the project's surface color as fill** — a hybrid. The `border: OutlineInputBorder(...)` plus `filled: true` produces a rounded, softly outlined field with the surface tone inside. M3 calls this "outlined" because the border draws the boundary.

The 16 dp corner radius is the project's `AppRadii.md`, applied uniformly to fields. Focused width is 1.2 instead of M3's 2 — a deliberate softening that matches the project's flat aesthetic.

Used in:
- [`lib/features/auth/ui/login_screen.dart`](../../lib/features/auth/ui/login_screen.dart)
- [`lib/features/drive/components/drive_dialogs.dart`](../../lib/features/drive/components/drive_dialogs.dart) — rename, new folder
- [`lib/features/drive/ui/drive_screen.dart`](../../lib/features/drive/ui/drive_screen.dart) — search

### Conventions

- **Always use `labelText`, never just `hintText`.** The label persists; the hint disappears on first character.
- **`errorText` for validation, `helperText` for hints.** They share the same slot and show the same height — switching between them doesn't re-flow the form.
- **`prefixIcon` for input affordances, `suffixIcon` for actions.** Search icon goes left; clear button goes right.

### Gaps

- **No state-layer overlays** for hover / focus on filled fields. The framework will paint them from M3 defaults, which expect `surfaceContainerHighest` as the base — but the project sets `surface` as fill. The hover state may be subtler than M3 intended. If hover affordance matters (desktop), explicitly set `hoverColor`.
- **`floatingLabelStyle` not set.** Inherits from `labelStyle` (which uses muted color). M3 promotes the floating label to `primary` on focus — the project's field promotes only the border, not the label. If field state needs to be more obvious, add a `floatingLabelStyle` override.
- **No dense variant defined.** Forms that need to fit more fields per screen would want `isDense: true` per-field — that's fine, but the heights aren't documented anywhere.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Fill on / off | `InputDecorationTheme.filled` | [line 225](../../lib/core/theme/app_theme.dart#L225) |
| Fill color | `InputDecorationTheme.fillColor` | [line 226](../../lib/core/theme/app_theme.dart#L226) |
| Border | `InputDecorationTheme.border` / `enabledBorder` / `focusedBorder` / `errorBorder` / `focusedErrorBorder` / `disabledBorder` | [lines 235-248](../../lib/core/theme/app_theme.dart#L235-L248) |
| Padding | `InputDecorationTheme.contentPadding` | [line 231](../../lib/core/theme/app_theme.dart#L231) |
| Label | `InputDecorationTheme.labelStyle` | [line 228](../../lib/core/theme/app_theme.dart#L228) |
| Hint | `InputDecorationTheme.hintStyle` | [line 227](../../lib/core/theme/app_theme.dart#L227) |
| Icon colors | `prefixIconColor` / `suffixIconColor` | [lines 229-230](../../lib/core/theme/app_theme.dart#L229-L230) |
