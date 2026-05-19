# Elevation

> Source: M3 elevation levels are described across the M3 spec and applied per-component in Flutter. Numeric values pulled from `_CardDefaultsM3` (1), `_DialogDefaultsM3` (6), `_SnackbarDefaultsM3` (6), `_BottomSheetDefaultsM3` (1), `_FABDefaultsM3` (6).

## Purpose

In M3, elevation does two things:

1. **Casts a shadow** — the traditional, physical-metaphor cue that one surface sits above another.
2. **Tints the surface** — a tonal overlay (`surfaceTintColor` on top of `color`) that makes a surface read as "elevated" without a shadow.

M3 increasingly relies on **tone** over **shadow** — the surface gets darker (in light mode) or lighter (in dark mode) as elevation increases. Shadows still apply but are subtler. The result is more accessible on low-contrast surfaces and looks better on dark mode.

## M3 elevation levels

| Level | Value (dp) | Where M3 uses it |
|---|---:|---|
| 0 | 0 | App bar (resting), bottom navigation, inline content |
| 1 | 1 | Card (elevated), bottom sheet, scrolled-under app bar |
| 2 | 3 | Top app bar (scrolled-under), small FAB hover, switch thumb |
| 3 | 6 | FAB, dialog, snackbar, navigation drawer |
| 4 | 8 | FAB hover, navigation drawer hover |
| 5 | 12 | Modal navigation (large), bottom sheet drag preview |

These are *Flutter's* level→dp mapping. When you write `elevation: 3` it produces a shadow consistent with M3 level 3.

## Surface tint

M3 components paint a `surfaceTintColor` overlay scaled by elevation:

```
effective surface color = lerp(color, surfaceTintColor, elevationOpacity(elevation))
```

`elevationOpacity` is a curve baked into the framework. At elevation 0 it's 0 (no tint). At elevation 12 it's roughly 0.14. The default `surfaceTintColor` is `colorScheme.surfaceTint` which Flutter sets to `colorScheme.primary` when seeded.

To turn surface tint OFF, set `surfaceTintColor: Colors.transparent` per-component.

## Project approach: tint disabled, shadows custom

The project sets `surfaceTintColor: Colors.transparent` everywhere — `appBarTheme`, `cardTheme`, `bottomSheetTheme`, `dialogTheme`, `navigationBarTheme`. Most components also have `elevation: 0`, which means no tint *and* no shadow. Surfaces are differentiated by tone explicitly (`surface`, `surfaceSubtle`) rather than by elevation.

The exceptions are the two custom shadow presets in [`AppShadows` at lib/core/theme/app_theme.dart:75-124](../../lib/core/theme/app_theme.dart#L75-L124):

### `AppShadows.card(brightness)`

Light mode:
```dart
[
  BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0c000000), blurRadius: 22, offset: Offset(0, 12), spreadRadius: -18),
]
```

Dark mode:
```dart
BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 16), spreadRadius: -18)
```

Two-layer in light mode (a tight 1 dp contact shadow + a soft drop). Single layer in dark mode (heavier opacity to read against dark surfaces).

### `AppShadows.floating(brightness)`

Light mode:
```dart
[
  BoxShadow(color: Color(0x05000000), blurRadius: 1, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0a000000), blurRadius: 16, offset: Offset(0, 8), spreadRadius: -4),
  BoxShadow(color: Color(0x0f000000), blurRadius: 32, offset: Offset(0, 24), spreadRadius: -8),
]
```

Dark mode:
```dart
BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 12))
```

Three-layer light-mode stack (contact + close + far) for a depth effect that doesn't read as a single fat shadow.

## Mapping M3 levels → project shadows

The project uses two presets, not six levels:

| M3 level | Project equivalent |
|---|---|
| 0 | No shadow (default) |
| 1 (card) | `AppShadows.card` if you want a card to lift |
| 3 (dialog, FAB, snackbar) | `AppShadows.floating` |
| 6 (drawer hover) | `AppShadows.floating` |

The current theme sets `elevation: 0` on cards, dialogs, sheets, snackbars, FAB — they don't get shadows automatically. To use the presets, apply them via `Container(decoration: BoxDecoration(boxShadow: AppShadows.floating(brightness)))`.

## Token gap (flagged for follow-up)

- **No M3 elevation level → preset mapping.** The two presets are named by purpose ("card", "floating") not by level. That's fine for the current flat aesthetic, but if the project ever wants real M3 elevation (FAB hover bumps, snackbar lifts), it'll need a 0–5 scale.
- **`surfaceTintColor: Colors.transparent` everywhere.** Document why: the project uses tonal differentiation via explicit `surfaceContainer*` colors, not via tint blending. The cost is that automatic scroll-under app-bar tinting is also off.
- **Hover elevation on filled buttons isn't overridden.** M3 says hover bumps from 0 → 1 dp. The project doesn't disable this in `filledButtonTheme`, so a hover shadow paints on desktop/web. Fix when desktop becomes a target.

## Best practices

- **Don't reach for shadows by default.** Use a hairline border (`outline` / `outlineVariant`) or a tone change (`surface` → `surfaceContainerLow`) first.
- **Reserve `AppShadows.floating` for transient surfaces** — sheets that detach during drag, popover menus, contextual cards that *aren't* in the normal flow.
- **`AppShadows.card` is for hover-style emphasis** — a card that the user is interacting with, not for every card.
- **Check both modes.** A shadow that works in light mode is often inadequate in dark mode (and vice versa). The project's brightness-aware factories handle this — keep using them.
