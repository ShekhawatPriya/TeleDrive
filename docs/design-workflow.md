# TeleDrive frontend design direction

## What changed

The interface now gives content different levels of emphasis: larger recent previews, folder collections, a photographic library cover, compact file rows, readable metadata, and floating controls. Layout and information hierarchy do the work; color remains the existing brand system. Account/profile composition, routes, repositories, backend APIs, storage contracts, and account isolation remain intact.

### Platform treatments

| Area | iOS | Android |
| --- | --- | --- |
| Navigation | Frosted floating dock, Cupertino press feedback | Opaque tonal dock, Material ink feedback |
| Photo filters | Cupertino sliding segmented control | Material choice chips |
| Collections | Quiet opaque surfaces with blue accents | Tonal grouping and larger shape treatment |
| Search | Rounded inset search field | Stadium search field |
| Settings switches | Adaptive Cupertino switches | Material switches |
| Secondary app bars | Centered titles by theme unless a screen overrides it | Leading titles by theme unless overridden |
| Viewer controls | Frosted dark floating toolbar | Opaque dark floating toolbar |

`AdaptiveSurface` is a Flutter approximation of frosted glass, not Apple's native Liquid Glass rendering engine. Glass is restricted to controls, with opaque fallbacks for high contrast, accessible navigation, and reduced animation. Flutter does not expose the independent iOS Reduce Transparency setting here; a native bridge is not implemented. Content cards stay opaque. Transitions retain the existing platform route behavior.

## Screen-by-screen review

Every routed page and the settings subpages were inspected in source. **Rendered** below means fixture-based widget rendering, not a live-device walkthrough. Retained pages were reviewed for continuity, not rebuilt gratuitously.

| Page / flow | Result | Evidence |
| --- | --- | --- |
| Splash | Centered real logo; matching native launch surfaces; no artificial delay | Flutter light/dark and accessibility fixtures; native handoff requires device review |
| Welcome | New collection illustration, stronger hierarchy, sign-in before supporting explanations | Rendered light/dark; 320px at 200% text |
| Login, code, password, country picker | Left-aligned introduction and stronger heading; form steps retained | Source review; existing auth regression tests |
| Device authorization | Clearer device-connection heading; real authorization progress retained | Source review; auth regression tests |
| Community onboarding | Existing setup preserved; success animation stops looping and honors reduced motion | Source review |
| Drive | Larger recents, secondary organizational destinations, folder collection cards, inset file rows | Rendered both platforms/light/dark; large text/high contrast |
| Folder | Inherits collection cards and refreshed file tiles; breadcrumbs/actions retained | Source review; folder operation regression tests |
| Photos | Actual-library cover, date groups, rounded thumbnails, working All/Photos/Videos controls | Rendered both platforms/light/dark; filter interaction; 1,000-item lazy-build check |
| Photo/video viewer | Floating controls, filename and position context; existing zoom/video/paging retained | Toolbar action test; pager/media source review |
| Photo details | Thumbnail/identity header, size/format facts, dimensions, folder, timeline and exceptional statuses | Rendered; scroll/overflow checks at 320px and 200% text |
| Starred | Collection introduction, stronger file presentation and large-text list fallback | Rendered both platforms/light/dark |
| Shared links | Permission and status visible; activity separated from title; revoked/expired labels use model state | Rendered both platforms/light/dark |
| Share detail | Clear access summary, wrapping Copy/Share actions, responsive counters | Rendered; both actions verified at normal/200% text |
| Create share / result / access log | Existing permission, expiry, revoke and result flows retained; theme continuity | Source review |
| File viewer | Larger page gutters; quiet metadata groups and readable values; motion accessibility refinement | Metadata render/overflow checks; source review |
| Account/profile sheet, account switcher | Main composition intentionally preserved | Source review; existing account tests |
| Storage profile | Main composition intentionally preserved | Existing large-text storage card render test |
| Data & Privacy | Main composition retained; entry motion honors reduced animation | Source review only |
| Free up space and confirmations | Existing verification, explanation and destructive confirmation layout retained | Source review only |
| Settings overview | Group structure retained, refined corner treatment | Source review |
| Server connection | Refined shared page header and group surfaces | Source review; backend connection regression tests |
| Upload settings | Refined header and native platform switch | Source review; app-settings regression tests |
| Backup settings / diagnostics | Shared header/group improvements; existing scan and controls retained | Source review; backup regression tests |
| Cache & Storage | Existing space summary retained; group/switch refinement | Source review; cache regression tests |
| Privacy & Security settings | Shared header/group/switch refinement | Source review; app-settings regression tests |
| Notifications settings | Shared header/group/switch refinement | Source review; app-settings regression tests |
| Archive / Locked | Collection context above recoverable items; existing restore/selection retained | Source review |
| Trash | Recovery-focused introduction; destructive controls retained | Source review |
| Project / Changelog | Android product hero, real maker artwork, content-sized social-link flow and editorial sections; iOS About composition and release timeline retained | Rendered Android light/dark and 320px/200% text; source review |
| App update | Existing status layouts retained; motion honors accessibility | Source review |
| Privacy / Terms | Existing sections retained; page transition honors reduced motion | Source review |
| Upload sheet, progress, selection, action menus | Existing actions retained; shell positions progress/FAB above the floating dock | Source review; selection/navigation regression tests |

The existing Data & Privacy diagnostic animation is not proof of real security tests. This visual pass does not certify the page's pre-existing security claims or run live diagnostic, upload, sharing, deletion, or account operations.

## Repeatable review workflow

1. Map a new screen to its main task, content, secondary actions, and all loading/empty/error states before styling it.
2. Reuse `AdaptiveSurface` for floating controls, `CollectionIntro` for collection context, and the file/folder components for content. Do not put every block into the same card or introduce blur behind body text.
3. Preserve real data boundaries. Loaded item counts must not masquerade as complete library totals; do not invent memories, storage metrics, or activity.
4. Render populated fixtures on both platforms, light/dark, 320px, large text, and high contrast. Keep fixtures separate from production providers. Inspect the PNGs as well as checking test results.
5. Exercise affected interactions and regression tests. Distinguish widget rendering, native compilation, and live device evidence.

```powershell
flutter test test/modernization_ui_test.dart test/navigation_shell_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
Start-Process (Resolve-Path build/modernization/index.html)
flutter analyze
flutter test
flutter build apk --debug --no-pub
```

Previews are written to `build/modernization/` (ignored build output). The test photo is licensed and attributed in `test/fixtures/design/ATTRIBUTION.md`; it is not a production asset. Test fonts approximate system fonts for portable rendering. The comparison gallery is an evidence browser, not a functioning app prototype.

## Validation and remaining device checks

- Before delivery: the full regression suite passed 122 tests before the final toolbar refinement; the targeted UI/navigation suite then passed 43 tests, including the toolbar and large-text/high-contrast screens. The subsequent folder-card iteration passed nine focused layout and interaction checks while retaining the 170dp card height.
- Static analysis: clean. Android debug APK: compiled locally.
- Native iOS build, iPhone gesture feel, independent Reduce Transparency behavior, TalkBack/VoiceOver on devices, and blur performance still require native device validation. No iOS simulator is available on this Windows host.
- No backend source, API, credentials, app version, or release/publishing configuration was changed. The debug APK was subsequently installed and launched on the user's Samsung SM-S906E with existing app data preserved. This confirms installation and launch, not a full live-account walkthrough.

## Design references

- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials): separate floating controls from content and preserve legibility.
- [Apple: Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/): material hierarchy and adaptation; used as direction, not a claim of native implementation.
- [Google: Expressive Material design research](https://design.google/library/expressive-material-design-google-research): emphasis through shape, typography and grouping.
- [Material adaptive layouts](https://m3.material.io/foundations/layout/canonical-examples/overview): retain a navigation rail for wider layouts.
- [Google Design on Airbnb](https://design.google/library/airbnb-invites-you-in): content-forward presentation with platform conventions.
- [Uber's Base Web introduction](https://www.uber.com/de/en/blog/introducing-base-web/): a shared system for spacing, typography and components. This is a systems reference, not a copy of Uber's current native app.

## Launch presentation

Startup uses a flat, monochrome box-and-plane mark, without the glossy launcher
tile, gradients, wordmark, spinner or minimum display time. The vector is painted
synchronously on Flutter's first frame. Authentication and routing still decide
when startup finishes.

Native and Flutter launch use the same 96-point artwork viewport and system
light/dark appearance. A saved in-app theme applies to the destination screen;
it must not recolor the mark midway through startup. Colors come from each
platform's existing surface/onSurface palette and exceed 7:1 contrast.

The source is `assets/icon/launch_mark.svg`. Run
`python scripts/generate_launch_mark.py`, then
`dart format lib/shared/launch_mark.dart` to regenerate the Flutter painter,
Android vector and iOS template PDF. Keep these generated outputs together.
The launcher icon and shared cloud symbols on other screens are unchanged.

Android uses a single 288dp vector viewport with 96dp artwork centered inside
it. Do not replace this with a bitmap inside fixed-size layer-list items:
system drawable scaling can produce a different visible size. The native exit
listener removes the system overlay when Flutter's first frame is ready,
without the default icon exit transformation. No network work delays that handoff.
Window fallback colors match the splash surface.

iOS uses the same vector geometry as a template PDF with dynamic foreground and
background colors. Its launch storyboard and Flutter share 96-point constraints.
Native iOS rendering and the OS-to-Flutter handoff still require Xcode/device QA.

Generate fixtures with:
`flutter test --no-pub test/splash_screen_test.dart --dart-define=WRITE_UI_PREVIEWS=true`.
They cover first-frame rendering, both platforms/themes, 320-point width,
200% text, high contrast, reduced motion and a saved/system-theme mismatch.
For Android changes, record a physical cold launch and inspect frames across
the native/Flutter boundary; widget fixtures alone cannot verify that handoff.

Android reference: https://developer.android.com/develop/ui/views/launch/splash-screen

The revised Android cold launch was recorded on a physical Samsung SM-S906E.
Frame inspection confirmed stable mark bounds and background across the
native/Flutter boundary, followed by the Drive screen. The OS entrance animation
remains system-owned. This verifies the device's current dark appearance;
light appearance has Flutter fixture coverage, not a separate physical run.

## Current Android Settings and status refinement

See [Android Settings design](android-settings-design.md) for the current
Material 3 Expressive treatment, primary research, country-flag correction,
shared/starred indicators and accessible Settings layouts. This supersedes the
earlier Android settings-group treatment above.

## Account confirmation banners

Backend sign-in does not display success over device authorization. Confirm the
added/reconnected account only after local authorization succeeds and the pending
account is committed. Entering the authorization route clears visible and queued
banners; cancellation and failed verification do not announce success.

Transient confirmations retain the avatar/card composition and the original
bottom alignment beside Add, with 16-point side insets. Reserve the measured
width of the visible Add button plus a 12-point gap. Without Add, the banner
uses the full available width at the same row height; it never moves above the
action row. Outside that row, use keyboard/safe-area clearance. Text wraps without a
two-line truncation limit. iOS uses the existing bounded Flutter glass surface
with a legibility tint and opaque high-contrast fallback; this is not native
UIKit Liquid Glass. Android uses an opaque Material inverse surface without blur.
Announcements use live-region semantics and reduced motion skips transitions.

References: [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials)
and [Android snackbars](https://developer.android.com/develop/ui/compose/components/snackbar).
Fixture/regression checks: `test/premium_toast_test.dart`, including light/dark,
320-point width, 200% text, high contrast and queued-confirmation cancellation.
