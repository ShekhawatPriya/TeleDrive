# Shape

> Source: M3 corner-radius values aggregated from `_CardDefaultsM3`, `_DialogDefaultsM3`, `_SnackbarDefaultsM3`, `_BottomSheetDefaultsM3`, `_FABDefaultsM3` and Flutter button source. M3 doesn't ship a single "shape scale" object in Flutter — each component carries its own default.

## Purpose

M3's shape system gives every component a corner radius from a small scale. The radius isn't decorative — it places the component on the visual hierarchy. Buttons (stadium) feel like actions. Cards (12) feel like grouped information. Sheets (28) feel like secondary surfaces. Mixing these is what makes a UI feel arbitrary.

## M3 shape scale (per-component values)

| Token | Radius (dp) | Components |
|---|---:|---|
| **Extra small** | 4 | Snackbar, chip (M3 chip is 8 — see below) |
| **Small** | 8 | Chip, switch track |
| **Medium** | 12 | Card (all variants), small FAB |
| **Large** | 16 | Sheet header (M2), regular FAB, extended FAB |
| **Extra large** | 28 | Dialog, bottom sheet (top corners), large FAB |
| **Full / pill** | ∞ | Button (stadium), FAB on the new spec, switch thumb |

Notes from the framework:
- **Cards**: 12 dp under M3 (`useMaterial3: true`), 4 dp under M2.
- **Bottom sheet**: 28 dp on the top edge only (`BorderRadius.vertical(top: 28)`).
- **Dialog**: 28 dp all around.
- **Snackbar**: 4 dp.
- **FilledButton / OutlinedButton / TextButton**: `StadiumBorder()` — fully rounded (radius = height / 2).
- **FAB**: 16 dp regular, 12 dp small, 28 dp large, 16 dp extended.
- **Text field (M3 default for outlined)**: 4 dp on `OutlineInputBorder` by default. Most projects override.

## Project shape scale

Defined in [`AppRadii` at lib/core/theme/app_theme.dart:65-73](../../lib/core/theme/app_theme.dart#L65-L73):

| Token | Value (dp) | Used for |
|---|---:|---|
| `AppRadii.xs` | 8 | (no current uses) |
| `AppRadii.sm` | 12 | (no current uses) |
| `AppRadii.md` | 16 | text-field outlines |
| `AppRadii.lg` | 20 | cards, list tile shapes, snackbar |
| `AppRadii.xl` | 24 | dialogs |
| `AppRadii.sheet` | 28 | bottom-sheet top corners |
| `AppRadii.pill` | 100 | filled buttons, FAB |

## Mapping — M3 vs project

| Surface | M3 default | Project | Comment |
|---|---:|---:|---|
| Snackbar | 4 | 20 | Project favors "soft pill" — large radius even on small surfaces |
| Card | 12 | 20 | Bigger; matches the chosen card identity |
| Text field | 4 | 16 | Bigger; matches button radius family |
| FAB | 16 | 100 (pill) | Pill — unifies button and FAB shape |
| Dialog | 28 | 24 | Slightly tighter |
| Sheet (top) | 28 | 28 | Matches |
| Buttons | stadium | stadium (100) | Matches |

## Conventions

- **The project shape system is "flat with generous radii"**. Don't introduce new radius values. If a new component needs a corner, it should pick from `AppRadii`.
- **Don't use the project's `xs` / `sm` tokens unless you specifically need them.** They're defined but unused. Document a use case before introducing one.
- **Bottom-sheet 28** is the one canonical M3 value the project keeps. Preserve it.

## Asymmetric shapes

`BorderRadius.vertical(top: ...)` — used for bottom sheets so only the top edges are rounded.
`BorderRadius.horizontal(left: ...)` — drawer / side-panel patterns.

The project uses `BorderRadius.circular` everywhere except sheets. No need for cut corners (`BeveledRectangleBorder`) — they're an M3 affordance the project explicitly doesn't lean on.

## Token gap

The project doesn't have explicit M3-aliased shape names (no `medium` → 12 token). Adding aliases isn't necessary as long as the team uses `AppRadii.*` consistently. If the project ever ships a public component library, alias the M3 names then.
