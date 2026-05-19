# Motion

> Source: M3 motion tokens reference and Flutter `Curves`/`Duration` constants. The project doesn't have a centralized motion file yet — values are scattered as literals in widgets.

## Purpose

M3's motion system gives every transition a duration and an easing curve from a small palette. Two principles:

1. **Emphasis** — important transitions (entering/exiting screens, sheets, dialogs) use slower, more shaped curves. Background transitions are quick and linear.
2. **Direction** — incoming elements use *deceleration* (start fast, end slow). Outgoing elements use *acceleration* (start slow, end fast). Two-way (interactive drag, reorder) uses *standard*.

## M3 easing tokens

| Token | Curve | Use |
|---|---|---|
| **Emphasized** | begins-fast, ends-slow with a stronger out-curve | Default for entering elements (sheets, dialogs, screens) |
| **Emphasized decelerate** | strong end-curve | Incoming elements that animate to rest |
| **Emphasized accelerate** | strong start-curve | Outgoing elements that leave the screen |
| **Standard** | symmetric ease-in-out | Two-way transitions (drag handle, switch toggle) |
| **Standard decelerate** | gentle out-curve | Subtle incoming animations |
| **Standard accelerate** | gentle in-curve | Subtle outgoing animations |
| **Linear** | linear | Continuous motion (progress bars, scrubbers) |

### Flutter equivalents

Flutter doesn't ship M3-named curves directly. Closest mappings:

| M3 token | Flutter `Curves.*` |
|---|---|
| Emphasized | `easeInOutCubicEmphasized` (M3-aligned) |
| Emphasized decelerate | `easeOutCubic` |
| Emphasized accelerate | `easeInCubic` |
| Standard | `easeInOut` |
| Standard decelerate | `easeOut` |
| Standard accelerate | `easeIn` |
| Linear | `linear` |

## M3 duration tokens

| Token | Value (ms) | Use |
|---|---:|---|
| **Short 1** | 50 | Selection, micro-interactions |
| **Short 2** | 100 | Switch toggle, ripple |
| **Short 3** | 150 | Small surface entry (chip, tooltip) |
| **Short 4** | 200 | Small modal in/out |
| **Medium 1** | 250 | Medium surface (small sheet, snackbar) |
| **Medium 2** | 300 | Large surface within screen |
| **Medium 3** | 350 | Dialog, large sheet |
| **Medium 4** | 400 | Same — slower for hero-style content |
| **Long 1** | 450 | Full-screen transition (incoming) |
| **Long 2** | 500 | Full-screen transition (outgoing pair) |
| **Long 3** | 550 | Container transform |
| **Long 4** | 600 | Same |
| **Extra long 1-4** | 700 / 800 / 900 / 1000 | Choreographed sequences, splash |

## Project motion (current state)

Durations and curves are scattered as literals across the codebase. Examples found in the audit:

- `260ms` (drive list animations)
- `180ms` (sheet drag-handle bounce)
- `320ms` (upload sheet entry)
- `Curves.easeOutCubic` (incoming)
- `Curves.easeInCubic` (outgoing)

Flutter framework defaults that apply implicitly:

| Constant | Value | Used by |
|---|---|---|
| `kThemeChangeDuration` | 200 ms | Theme color transitions, button state changes |
| `kRadialReactionDuration` | 100 ms | Ripple |
| `kTabScrollDuration` | 300 ms | TabBar scroll |
| `Material.defaultIconColorTween` | 200 ms | IconTheme color changes |

## Recommendation: centralize

Add a `MotionTokens` class to [lib/core/theme/](../../lib/core/theme/) (or alongside `app_theme.dart`):

```dart
class MotionDurations {
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);
  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);
  static const long1 = Duration(milliseconds: 450);
  static const long2 = Duration(milliseconds: 500);
}

class MotionCurves {
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Curves.easeOutCubic;
  static const emphasizedAccelerate = Curves.easeInCubic;
  static const standard = Curves.easeInOut;
  static const standardDecelerate = Curves.easeOut;
  static const standardAccelerate = Curves.easeIn;
}
```

Then map current literals:

| Current literal | Token replacement |
|---|---|
| `Duration(milliseconds: 180)` | `MotionDurations.short3` (150) — round to spec |
| `Duration(milliseconds: 260)` | `MotionDurations.medium1` (250) |
| `Duration(milliseconds: 320)` | `MotionDurations.medium2` (300) |
| `Curves.easeOutCubic` | `MotionCurves.emphasizedDecelerate` |
| `Curves.easeInCubic` | `MotionCurves.emphasizedAccelerate` |

This is a follow-up task — not part of these docs.

## Component-level guidance

| Component | Duration | Curve |
|---|---|---|
| Filled button state change | `kThemeChangeDuration` (200) | `linear` (state-layer fade) |
| Modal bottom sheet entry | `medium2` (300) | `emphasizedDecelerate` |
| Modal bottom sheet exit | `medium1` (250) | `emphasizedAccelerate` |
| Dialog entry/exit | `medium2` (300) | `emphasizedDecelerate` / accelerate |
| Snackbar in/out | `medium1` (250) | `emphasizedDecelerate` |
| Drag handle bounce | `short3` (150) | `standard` |
| Page transition | `long1` (450) | `emphasized` |
| Ripple | 100 | linear |
| Switch toggle | `short2` (100) | `standard` |

## Reduced-motion

`MediaQuery.of(context).disableAnimations` is true when the OS reduce-motion setting is on. For long page transitions and hero animations, fall back to `Duration.zero` or a short fade. Most material components handle this automatically; custom animations need to check.

```dart
final reduceMotion = MediaQuery.of(context).disableAnimations;
final duration = reduceMotion ? Duration.zero : MotionDurations.medium2;
```

## Token gap (flagged for follow-up)

- **Centralize**: replace scattered literals with `MotionDurations` / `MotionCurves` constants.
- **Audit reduce-motion compliance**: ensure custom animations respect `disableAnimations`.
- **Align curve choice with direction**: outgoing animations should use accelerate curves; incoming should decelerate. Check existing transitions for misuse.
