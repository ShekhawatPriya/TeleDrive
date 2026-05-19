# Progress indicators

> Source: [Flutter source — `_LinearProgressIndicatorDefaultsM3` and `_CircularProgressIndicatorDefaultsM3` in `progress_indicator.dart`](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/progress_indicator.dart). M3 defaults that ship under `useMaterial3: true`.

## Purpose

A progress indicator shows that work is happening. M3 distinguishes:

- **Linear** — for known or measurable durations (file upload, page load with progress).
- **Circular** — for short or indeterminate waits (loading data, waiting on a network response).

## Linear specs (M3 defaults — current)

| Property | Value |
|---|---|
| `color` | `primary` |
| `linearTrackColor` | `secondaryContainer` |
| `linearMinHeight` | 4 |
| `borderRadius` | 2 (i.e., `Radius.circular(2)` — 4 dp height / 2) |
| `stopIndicatorColor` | `primary` |
| `stopIndicatorRadius` | 2 |
| `trackGap` | 4 |

The "stop indicator" is a small dot at the end of the active progress (the M3 visual cue that shows the head of the progress).

### Linear — 2023 M3 (legacy)

If a project pinned to the 2023 M3 spec, `borderRadius`, `stopIndicator*`, and `trackGap` aren't set — flat bar with no end dot.

## Circular specs (M3 defaults — current)

| Property | Value |
|---|---|
| `color` | `primary` |
| `circularTrackColor` | `secondaryContainer` (determinate only) / `null` (indeterminate) |
| `strokeWidth` | 4 |
| `strokeAlign` | `strokeAlignInside` |
| `constraints` | `minWidth: 40, minHeight: 40` |
| `circularTrackPadding` | `EdgeInsets.all(4)` |
| `trackGap` | 4 |

### Circular — 2023 M3 (legacy)

| Property | Value |
|---|---|
| `color` | `primary` |
| `strokeWidth` | 4 |
| `strokeAlign` | `strokeAlignCenter` |
| `constraints` | `minWidth: 36, minHeight: 36` |
| (no track) | — |

## Indeterminate vs determinate

| Mode | When | API |
|---|---|---|
| Determinate | You know the percentage. Show real progress. | `LinearProgressIndicator(value: 0.0..1.0)` / `CircularProgressIndicator(value: 0.0..1.0)` |
| Indeterminate | You don't know how long it will take. | `value: null` (or omit) |

Indeterminate circular indicators don't paint a track by default (`circularTrackColor` is null) — they're a single sweeping arc.

## Accessibility

- The indicator itself is decorative. Wrap it (or its parent) with `Semantics(label: 'Loading…')` so screen readers announce *what* is in progress.
- For long determinate operations, surface the percentage in text near the bar — visual progress + numeric progress is more reliable than visual alone.
- Don't replace a result with a perpetual indeterminate spinner. If the operation takes longer than 10 s, switch to a "still working" message or a cancel option.

## In this project

[`progressIndicatorTheme` at lib/core/theme/app_theme.dart:374-378](../../lib/core/theme/app_theme.dart#L374-L378):

```dart
color: primary,                       // matches M3
linearTrackColor: surfaceSubtle,      // diverges: M3 secondaryContainer
circularTrackColor: surfaceSubtle,    // diverges: M3 secondaryContainer
```

The track color shift is meaningful. M3 uses `secondaryContainer` (a tinted surface) so the track has a slight color cue. The project uses `surfaceSubtle` — a near-canvas off-white — keeping the visual completely monochrome.

`strokeWidth`, `linearMinHeight`, and the M3 stop indicator / track gap aren't overridden. They render at M3 defaults (4 dp).

Used in:
- [`lib/features/upload/ui/components/upload_progress_bar.dart`](../../lib/features/upload/ui/components/upload_progress_bar.dart) — `LinearProgressIndicator`, the main use
- (No `CircularProgressIndicator` in current code — verify when adding loading states)

### Conventions

- **Linear for upload/transfer** — the project's upload sheet uses determinate linear progress with a numeric percentage.
- **Indeterminate circular for fetches** when added — keep the M3 4 dp stroke; it reads as "system" rather than "branded".
- **Don't reach for custom progress widgets**. The themed `LinearProgressIndicator` is consistent across screens.

### Gaps

- **No `CircularProgressIndicator` in use.** When a screen needs one, the existing theme will paint it ink-on-surface-subtle. That's correct, but verify the strokeWidth feels right with the rest of the surface (4 dp can feel chunky on small targets — drop to 2 if so via per-call override).
- **Stop indicator on linear bar.** The M3 stop indicator shows where the progress head is. That's enabled by default. If it's visually distracting in the upload sheet, set `stopIndicatorRadius: 0` per-call.

## Flutter mapping

| M3 token | Flutter property | Where set |
|---|---|---|
| Active color | `ProgressIndicatorThemeData.color` | [line 375](../../lib/core/theme/app_theme.dart#L375) |
| Linear track | `linearTrackColor` | [line 376](../../lib/core/theme/app_theme.dart#L376) |
| Circular track | `circularTrackColor` | [line 377](../../lib/core/theme/app_theme.dart#L377) |
| Stroke / height | `linearMinHeight` / `strokeWidth` | not themed (M3 default 4) |
