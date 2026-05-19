# Layout

> Source: M3 layout guidance combined with project's `AppSpacing` tokens.

## Purpose

A consistent layout language means screens feel related — not because they share components, but because they share rhythm. M3's layout system is built on a small set of breakpoints, a spacing scale, and a notion of *density* that lets the same component fit on a phone and a tablet without redesigning it.

## Spacing scale

The project's [`AppSpacing` at lib/core/theme/app_theme.dart:55-63](../../lib/core/theme/app_theme.dart#L55-L63):

| Token | Value (dp) | Use |
|---|---:|---|
| `xxs` | 4 | Inline gap between adjacent elements (icon ↔ text in a button) |
| `xs` | 8 | Tight padding (chip internal, dense list rows) |
| `sm` | 12 | Default content padding inside compact components |
| `md` | 16 | Standard screen edge gutter, card internal padding |
| `lg` | 24 | Section break, card-to-card gap |
| `xl` | 32 | Major section break, vertical hero spacing |
| `xxl` | 40 | Top-of-screen breathing room, empty-state spacing |

This is a 4 dp grid (every value is a multiple of 4). Stick to the grid — non-grid spacings cascade into visual jitter.

## M3 breakpoints

| Breakpoint | Width range (dp) | Devices |
|---|---|---|
| Compact | 0 – 599 | Phone portrait |
| Medium | 600 – 839 | Phone landscape, small tablet portrait |
| Expanded | 840 – 1199 | Tablet landscape, small laptop |
| Large | 1200 – 1599 | Desktop |
| Extra-large | 1600 + | Wide desktop |

In Flutter, read via `MediaQuery.of(context).size.width` or use `LayoutBuilder` for component-local breakpoints.

```dart
final width = MediaQuery.sizeOf(context).width;
final isCompact = width < 600;
final isMedium = width >= 600 && width < 840;
```

## Layout patterns by breakpoint

| Breakpoint | Navigation | Content |
|---|---|---|
| Compact | Bottom navigation bar / FAB / modal sheets | Single column, full-width cards |
| Medium | Navigation rail (icons only) | Single or two-column; sheets become side panels |
| Expanded | Navigation rail (icons + labels) | Two columns, fixed gutters |
| Large | Navigation drawer | Three-column or master/detail |

This project is mobile-only currently — compact only.

## Edge gutters

| Surface | Edge gutter (dp) |
|---|---:|
| Phone (compact) | 16 (`AppSpacing.md`) |
| Tablet (medium/expanded) | 24 (`AppSpacing.lg`) |
| Desktop (large) | 32+ (`AppSpacing.xl`) |

Gutters are the empty space between a screen's content and its left/right edges. They scale with breakpoint so wider screens feel less crowded. The project should use `AppSpacing.md` for screen padding by default; consider scaling up later if tablet support is added.

## Visual density

`Theme.of(context).visualDensity` controls how compact components are. Defaults:

| Platform | `visualDensity` |
|---|---|
| Mobile (Android, iOS) | `VisualDensity.standard` |
| Desktop (Linux, Windows, macOS) | `VisualDensity.compact` |
| Web | `VisualDensity.standard` |

`VisualDensity.compact` shaves about 8 dp off the height of `ListTile`, button, and other components — it's how desktop apps fit more on screen without redesigning. Don't override globally unless you mean to.

For project-wide adjustment, set in `ThemeData(visualDensity: VisualDensity.adaptivePlatformDensity)` — that picks compact on desktop, standard on mobile automatically.

## Common spacing patterns

| Context | Pattern |
|---|---|
| Card internal padding | `EdgeInsets.all(AppSpacing.md)` (16) |
| List section gap | `SizedBox(height: AppSpacing.lg)` (24) |
| Form field vertical gap | `SizedBox(height: AppSpacing.md)` (16) |
| Inline icon ↔ label gap | `SizedBox(width: AppSpacing.xs)` (8) |
| Screen edge gutter | `EdgeInsets.symmetric(horizontal: AppSpacing.md)` (16) |
| Sheet content padding | `EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg)` |

## Safe areas

Always wrap top-level content in `SafeArea` (or `Scaffold` which handles it automatically). On iOS, the bottom safe area accounts for the home indicator. On Android, it's the navigation bar.

For bottom sheets, pass `useSafeArea: true` to `showModalBottomSheet` so the sheet doesn't hide content behind the gesture bar.

## Touch vs mouse target sizes

A 48 × 48 tap target on mobile is a 32 × 32 click target on desktop (the precision is higher with a mouse). Flutter uses `materialTapTargetSize` to adjust — default `padded` for mobile, `shrinkWrap` for some desktop components. Don't shrink interactive elements below 48 dp on mobile even if the visual content fits in 24 dp.

## Project conventions

- **Use `AppSpacing` tokens, not literals.** A `padding: 17` in code is a smell — it signals either a token mismatch or a misalignment with the rest of the screen.
- **Stack via `SizedBox(height: AppSpacing.X)` rather than `Padding` when separating siblings**. Easier to read; doesn't introduce nested padding.
- **Don't reach for `Spacer()` for fixed gaps.** Use `SizedBox`. `Spacer` is for proportional layout (push button to bottom of column).
- **Edge gutter on screens is `AppSpacing.md` (16)** unless the design calls for full-bleed.

## Token gap

- **No breakpoint constants** — when this app expands to tablet, define `AppBreakpoints.compact = 600`, etc., to avoid magic numbers in `LayoutBuilder` calls.
- **No density adaptation.** `visualDensity` defaults to standard. If desktop ever ships, set `visualDensity: VisualDensity.adaptivePlatformDensity` in `ThemeData`.
