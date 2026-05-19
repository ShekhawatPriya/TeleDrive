# M3 Reference Docs (project-scoped)

Spec-level Material 3 reference for this Flutter app, sourced from [m3.material.io](https://m3.material.io/) and scoped to the components actually in use.

## How to use

- **Building or modifying a UI surface?** Open the matching component doc, check the `## Specs` and `## States` tables, and use the `## Flutter mapping` to find the right `ThemeData` property.
- **Touching theme tokens?** Start in [styles/](styles/). Each style doc tracks where the corresponding token lives in [`lib/core/theme/app_theme.dart`](../../lib/core/theme/app_theme.dart).
- **Want the philosophy?** [foundations/](foundations/).

## Structure

| Section | Contents |
|---|---|
| [foundations/](foundations/) | Accessibility, layout/spacing, interaction states |
| [styles/](styles/) | Color, typography, shape, elevation, motion, state layers |
| [components/](components/) | Spec sheets for every M3 component used in the app |
| [flutter/](flutter/) | M3 token → Flutter `ThemeData` cheatsheet |

## Coverage

These docs cover the M3 surface the app uses today. New components should get a doc here when adopted. Currently in scope:

- **Buttons**: filled, FAB
- **Containers**: card, list (ListTile), divider
- **Selection**: checkbox
- **Inputs**: text field
- **Communication**: dialog, snackbar, modal bottom sheet, tooltip, linear progress
- **Structure**: scaffold, app bar

Out of scope until adopted: navigation rail/bar/drawer, chips, banners, badges, radio, switch, slider, dropdown menu, search bar, date/time pickers, segmented button, the elevated/outlined/text/tonal button variants.

## Per-doc shape

Every component doc has the same sections so they're scannable:

1. **Purpose** — one or two sentences from the M3 spec
2. **Anatomy** — numbered parts with token names
3. **Specs** — sizes, padding, target sizes, corner radius, color roles, typography, elevation
4. **States** — table of state × visual change × state-layer opacity × color role
5. **Accessibility** — contrast, target size, focus, screen reader notes
6. **Variants** — when to use which
7. **In this project** — file paths, current gaps, custom wrappers
8. **Flutter mapping** — M3 token → Flutter property

## Token gaps to fix later

These were flagged during the audit and are noted in the relevant style docs. Not fixed by these docs — separate task:

- Centralize **motion** tokens (durations and easings are scattered as literals)
- Define **state-layer** opacities
- Replace 2-preset shadows with **elevation** levels 0–5
- Document the rationale for `surfaceTintColor: Colors.transparent`
- Add a **semantic alias** `ThemeExtension` for app-specific color roles

See [styles/motion.md](styles/motion.md), [styles/state-layers.md](styles/state-layers.md), and [styles/elevation.md](styles/elevation.md) for details.

## Source

[m3.material.io](https://m3.material.io/) is the canonical M3 reference but it's a client-rendered SPA — the HTML body has no spec content, so it can't be fetched programmatically. These docs use [api.flutter.dev](https://api.flutter.dev/) as the primary source instead, since:

1. The values are the same (Flutter Material is a faithful M3 implementation).
2. They're directly actionable — every spec maps to a Flutter property the team can wire up.
3. They're verifiable — the page is fetchable and the source-of-truth for what `useMaterial3: true` actually applies.

Where anatomy or visual specs aren't covered by the API docs, the Material Components GitHub repos (`material-components/material-components-android`, `material-components/material-web`) are used. Each doc cites its source URL.

Pages were captured 2026-05-19.
