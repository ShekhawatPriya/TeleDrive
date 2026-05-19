# Accessibility

> Source: M3 accessibility guidance combined with WCAG 2.1 / 2.2 requirements that Flutter Material implements. Per-component a11y notes live in the component docs; this is the cross-cutting summary.

## Targets

| Requirement | Value | Where it shows up |
|---|---|---|
| Minimum tap target | 48 × 48 dp | All interactive controls |
| Minimum visible icon area | 24 × 24 dp | Icon-only buttons (the surrounding tap target inflates) |
| Minimum text size | 12 sp | `bodySmall`, `labelMedium`, `labelSmall` |
| Body text contrast (WCAG AA) | ≥ 4.5:1 | Default text against surface |
| Large text contrast (≥ 18 sp regular or ≥ 14 sp w500) | ≥ 3:1 | Headlines, button labels |
| Non-text UI contrast (icons, borders that convey meaning) | ≥ 3:1 | `outline` (not `outlineVariant`), focus rings |
| Decorative borders | no requirement | `outlineVariant`, divider |

Flutter inflates tap targets via `materialTapTargetSize: padded` (the default). A 24 dp icon inside an `IconButton` gets a 48 × 48 hit region automatically. Don't disable that without a reason.

## Color and contrast

The M3 color roles are paired so `on*` colors meet AA contrast against their base — `onPrimary` on `primary` is ≥ 4.5:1 by construction. Verify when:

- Customizing roles via `copyWith` (this project does this — see [styles/color.md](../styles/color.md)).
- Using `tertiary` for a non-text element (e.g., a colored chip background) — the spec doesn't guarantee the same pairing.
- Disabled states. M3 uses `onSurface @ 0.38` for disabled foregrounds, which is below AA for body text. Disabled is allowed to be sub-AA *as long as* the element is genuinely non-interactive — but don't use it for content the user must read.

### Project-specific contrast checks

- `bodyMedium` and `bodySmall` default to `AppColors.mute` (#888) — that's `≈ 4.6:1` on `#fafafa`, `≈ 4.6:1` on `#000`. Right at the line. New backgrounds need verification.
- `outlineVariant` and `outline` are the same value in this project (`hairline`/`darkHairline`). For decorative dividers this is fine. For borders that distinguish a tappable element from its background (e.g., the project's outlined card), the value should clear 3:1 — `#ebebeb` on `#fafafa` is **~1.1:1**, well below. The card's tap affordance comes from the content, not the border.

## Focus

Keyboard focus is its own a11y pillar — independent from touch.

| Element | Focus indicator |
|---|---|
| Filled button | `onPrimary @ 0.10` overlay (state layer) |
| Outlined button | 1 dp outline thickening + state layer |
| Text field | 2 dp `primary` border (replaces 1 dp default) |
| ListTile | `onSurface @ 0.10` state layer |
| Checkbox | 2 dp `onSurface` border + `onSurface @ 0.10` state layer |

Don't disable the framework's focus indicators. If you need to restyle a focus ring, use `focusColor` / `overlayColor` rather than removing it.

## Semantics

Flutter's accessibility tree is built from `Semantics` widgets — `Text`, `IconButton`, `Switch`, etc. produce them automatically. You add explicit `Semantics()` when:

- An icon carries meaning the screen reader can't infer (no `tooltip:`, no enclosing labeled container).
- A custom widget composes multiple controls into one logical element.
- A live region needs to announce changes (a snackbar already does this; loading text in your own widget needs `Semantics(liveRegion: true)`).

### Common mistakes

- **Decorative icons announced as content.** `Icon(Icons.dot)` next to text gets read aloud. Wrap with `ExcludeSemantics`.
- **`GestureDetector` on a non-button.** Adds tap behavior but no semantics. Use `InkWell` or `TextButton` instead — they label correctly.
- **Custom checkboxes/switches without `toggled`.** A widget that toggles state needs `Semantics(toggled: ...)` so screen readers announce "checked" / "not checked".

## Reduced motion

`MediaQuery.of(context).disableAnimations` is true when the OS reduce-motion setting is on. For long page transitions and hero animations:

```dart
final reduce = MediaQuery.of(context).disableAnimations;
final duration = reduce ? Duration.zero : MotionDurations.medium2;
```

Most Material widgets handle this automatically. Custom animations don't — check.

## Text scaling

`MediaQuery.textScaler` reflects the OS text-size setting. The framework scales `TextStyle.fontSize` automatically. Things that break:

- **Hardcoded heights on text containers** (e.g., `SizedBox(height: 20, child: Text(...))`). The text grows; the container doesn't.
- **`overflow: TextOverflow.ellipsis` without `maxLines`.** Single-line ellipsis is fine; if the text needs more rows on bigger sizes, set `maxLines: 2` or remove the overflow.
- **App bars at maximum scale.** The framework caps title text scaling at 1.34 to keep actions visible.

For forms with mandatory field labels, consider `Text.rich` with non-scaling spans for unit labels (e.g., the "$" prefix on a price field) and let the user value scale freely.

## RTL

`Directionality` flips most layout — `EdgeInsetsDirectional.only(start:, end:)` instead of `left:`/`right:`. The project should be testing in RTL but check:

- **Custom paint** (gradients, shadows that go "left to right") doesn't auto-flip.
- **Icons that imply direction** (back arrow, send arrow). Use `Icons.arrow_back` (auto-mirroring) over `Icons.chevron_left`.

## Per-component a11y references

| Component | Key a11y note | Doc |
|---|---|---|
| FilledButton | Label text in `labelLarge`. 48 dp tap target via `materialTapTargetSize`. | [components/buttons.md](../components/buttons.md) |
| ListTile | Tappable leading/trailing must be ≥ 48 × 48; 56 dp default tile height satisfies. | [components/lists.md](../components/lists.md) |
| Checkbox | 40 dp visual area + 48 × 48 tap region. Errors must use more than color. | [components/checkbox.md](../components/checkbox.md) |
| TextField | Floating label is the AA pattern. Always label, don't rely on hint. | [components/text-fields.md](../components/text-fields.md) |
| Tooltip | Always set on icon-only `IconButton` — that's the screen-reader label. | [components/tooltip.md](../components/tooltip.md) |
| Dialog | Modal trap focus, AT announces as modal. Don't put long content in `AlertDialog`. | [components/dialogs.md](../components/dialogs.md) |
| Snackbar | `liveRegion` semantic — interrupts AT. Don't fire for noise. | [components/snackbar.md](../components/snackbar.md) |

## Verification

Full WCAG validation requires testing with assistive technology and expert review. What's checkable in code:

- `flutter test --reporter expanded test/path_to_a11y_test.dart` — `tester.semantics` matchers verify labels/roles.
- `flutter analyze` — flags missing `tooltip` on `IconButton` (in newer SDKs).
- Manual check: navigate the app with TalkBack (Android) or VoiceOver (iOS) and confirm focus order, labels, and announcements.
