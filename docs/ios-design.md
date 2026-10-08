# iOS design

Reference: `/Users/sree/Code/PNL/Passwords`, including its Cupertino page structure
and UIKit glass-button platform view. Brand colors are app tokens, not an
Apple-mandated hex palette.

Apple references:
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [UIKit's new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- [UIButton menus](https://developer.apple.com/documentation/uikit/uibutton/menu)

## Color system

UIKit controls (tab bar, toolbars, search field, glass buttons, menus) are tinted
with `.systemBlue` and `.systemRed`. `iosPalette` uses the same values for Flutter
content (`#007AFF`/`#0A84FF`, Increase Contrast `#0040DD`/`#409CFF`), so native
chrome and Flutter content share one accent. Filled buttons keep white labels in both themes. Every
`ColorScheme` role is overridden on iOS, so seeded Material tones (blue-grey
outlines, tinted toasts, tonal elevation) do not appear; `surfaceTint` is
transparent. High-contrast themes pass `highContrast: true` through `buildTheme`.

Settings-style icon tiles take their colour from `IosTint`, one system colour per
destination or media kind (for example Photo Backup is indigo and Telegram
Drive is blue wherever they appear). `IosRow` resolves these dynamic colours,
so dark mode receives UIKit's dark variants. `IosGroup` headings use title case,
not uppercase. `test/ios_palette_test.dart` checks UIKit parity and contrast floors.

## Native controls

`NativeTabBar` embeds UIKit's `UITabBar`, including SF Symbols, the system glass
selection lens and native touch handling. Flutter owns the existing tab routes;
UIKit sends selection events and receives updated index/appearance values.
Android retains its separate Flutter navigation.

On wider iPad layouts, the shell uses a scrollable Cupertino sidebar with the
same destinations and route callbacks. Android keeps its Material navigation
rail. Selected semantics, 48-point minimum targets and wrapping labels remain
available at larger text sizes. This sidebar is Flutter-rendered, not a native
`UITabBarController` sidebar.

`NativeGlassButton` uses `UIButton.Configuration.glass()` on supported iOS.
Overflow buttons use a real `UIMenu` with `UIAction` entries. An uncached deferred
menu requests a fresh Dart snapshot each time it opens, preserving callbacks,
checkmarks, subtitles and destructive state. Layout and sorting are submenus.
Missing native bridges fall back to working Flutter controls for tests/old hosts.

The glass APIs remain guarded at iOS 26, where they were introduced. Menu
subtitles have their own iOS 16 availability guard, preserving the iOS 15
deployment target. Rebuilding with a newer SDK does not require raising either
availability check to iOS 27.

Unchanged button/tab/selection configurations do not trigger repeated bridge
updates. Native toolbar items and photo buttons are retained across selected,
enabled and appearance updates; their callbacks read the current action label.
Menu contents still resolve afresh on every opening.

`IosAccessibility` surrounds the Navigator and overlays. Its native preference
bridge reads and observes Reduce Transparency, and refreshes on foregrounding.
Flutter navigation materials use an opaque fallback for that setting as well
as increased contrast. UIKit continues to own native glass adaptation.
The upload source chooser receives the app's resolved appearance as well as its
measured anchor, so it matches explicit Light/Dark choices independently of the
device appearance.

TeleDrive combines native UIKit Liquid Glass controls with Flutter Cupertino
layouts. Account/Settings navigation bars are Cupertino widgets; they are not
native `UINavigationBar` instances. `AdaptiveSurface` remains a Flutter frosted
material approximation. The conventional full-bleed PNG launcher icon remains
valid; a layered Icon Composer icon is a separate artwork enhancement.

## Account destinations

The iOS `/account` route is a dedicated `CupertinoPage` with a compact `IosPage`
header and standard Back control. It supports the Cupertino edge-back gesture.
Destinations push above Account; Back returns to Account, preserving its scroll
and expanded switcher state. Android retains its account sheet. Saved account
rows include `ProfileAvatar` and keep the existing switch/remove contracts.

`IosPage`, `IosGroup` and `IosRow` provide Cupertino large-title navigation,
inset lists, disclosure indicators, switches and accessible wrapping text.
Account, Settings, nested settings, Telegram Drive, My Data and Free Up Space
have iOS-specific compositions. Android retains its existing screens.

Appearance uses three full-width selection rows (Light, Dark, System), with one
checkmark and an explanation of System mode. Each row is at least 44 points high
and exposes selected semantics. Theme preference storage is unchanged.

My Data's iOS presentation shows actual session and storage information. It does
not present the legacy timer-driven diagnostics as a completed security audit.
Free Up Space preserves the existing scan/delete controller and presents a
Cupertino confirmation before the system Photos confirmation.

## Verification

- Dart analyzer: no issues.
- 70 focused tests: appearance selection/touch targets, 2× text at 320 points,
  open-sheet dark-to-light updates, account and settings pages, data/storage/free
  space, native-menu payload/callbacks, account switching and navigation.
- Native iOS compilation succeeded.
- iOS 26.5 simulator: inspected actual UIKit tab selection, overflow menus and
  submenus; verified updated checkmarks, account-to-settings navigation and
  Light/Dark appearance selection. Physical target runs iOS 27.

`tools/ios_design_preview.dart` is an isolated fixture entry point for simulator
visual QA. It uses example data and is never imported by `lib/main.dart`.
Use `-t lib/main.dart` for production/device runs. Widget previews are generated
under `build/modernization` with portable fonts; they do not render native UIKit.

Focused checks:

```sh
flutter --suppress-analytics analyze --no-pub
flutter --suppress-analytics test --no-pub test/ios_appearance_picker_test.dart test/modernization_ui_test.dart test/native_menu_payload_test.dart test/navigation_shell_test.dart test/ios_action_contract_test.dart test/switch_account_provider_test.dart --dart-define=WRITE_UI_PREVIEWS=true
```

## Browsing surfaces and share details

Following device review, iOS browsing cards now let thumbnails and captions sit directly on the page.
Folder tiles use pale blue in light mode and black with a subtle outline in
dark mode, per the user’s selected treatment. System-blue folder symbols keep
their identity distinct from file thumbnails. File grid dimensions, recents geometry and home
section order are retained. List rows use compact 40-point thumbnails and inset
hairline dividers, with format, file size and a full modified date. Star status
is shown on the thumbnail; starring remains available through item actions.

Custom action sheets use opaque material with no glass outline. Their compact grouped action layout preserves drag/scroll behavior. UIKit navigation and native
menus retain the system's glass rendering.

Share details use an unboxed summary, Cupertino copy/share controls, access and
expiry metadata, inline counters and a simple activity list. Android retains its
existing card/list styling.
The Share detail and item-menu revoke actions use the native
`person.crop.circle.badge.minus` symbol (and matching Cupertino fallback), labeled
“Revoke link” / “Revoke share”. The confirmation explains that access ends;
Android retains its broken-link icon.

Surface validation: 74 tests passed across modernization UI, glass/opacity,
iOS action contracts, platform folder UI and navigation. Pixel sampling verifies
that changing the backdrop does not change the action sheet's interior color.
Light/dark fixture previews include `ios-file-list-*`, `ios-file-grid-*`,
`ios-item-sheet-*`, and `ios-share-*` under `build/modernization`.


Action-sheet edge refinement: the route no longer applies a second corner clip.
The inset surface uses continuous superellipse corners, consistent horizontal
insets, and safe-area clearance above the home indicator and keyboard. The
thumbnail shares a single clipped boundary, and filenames use a compact
single-line header instead of wrapping inside the extension. Additional route
geometry tests cover a 402-point iPhone with and without a 260-point keyboard.


## Compact action sheets

Add to Drive uses one group of three 48-point-minimum action rows, with a compact
17-point heading and a drag indicator. Labels carry the choice; redundant
promotional copy and per-action descriptions are omitted. File/folder sheets use
a 44-point identity preview and real metadata, followed by the same grouped rows
for frequent actions, organization, and destructive actions. Share/Star no longer
occupy oversized shortcut cards. Opaque semantic group surfaces, 16-point group
insets, four-point group margins, and hairline separators establish hierarchy.
Rows grow with text scaling; constrained sheets remain scrollable.

The iOS create/rename editor presents the name field and confirmation directly,
without repeating the name in a decorative folder preview. Android keeps its
Material controls and folder preview. Action IDs, confirmations, keyboard submit,
and dismissal-before-navigation contracts remain unchanged.

Reproduce the additional Add to Drive previews and create-folder handoff checks
with `flutter test --no-pub test/platform_folder_ui_test.dart --dart-define=WRITE_UI_PREVIEWS=true`. This covers both platforms/themes and
320-point, 200% text/high-contrast layouts. Native UIKit and device interaction
remain separate from these Flutter fixture checks. Shared sheet headings and
Material action labels wrap at enlarged text sizes instead of truncating.


## Sheet dismissal

Dismissible iOS Add to Drive, file/folder action, create/rename, move-destination,
and country-picker sheets omit the redundant header cross. Headers reclaim that
space with balanced insets. Swipe down from the sheet header/drag indicator or tap
the backdrop to cancel; the indicator also exposes a semantic dismiss action to
assistive technology. Scrollable content and keyboard-safe geometry are retained.
Account is now a dedicated page with Back and no close button. Android
controls, text-field clear buttons, transfer cancellation, and confirmation-alert
choices retain their existing roles.

This is an application-specific simplification informed by Apple's
[Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets),
[Color](https://developer.apple.com/design/human-interface-guidelines/color), and
[Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
guidance. The restrained appearance uses the existing semantic neutral surfaces,
blue action accents, system typography, and subtle separators; no new palette or
body glass is introduced.

Regression checks cover header drag, backdrop, keyboard Escape and semantic
dismissal, null results on cancellation, action results, and the profile close
exception. The `platform_folder_ui_test.dart`, `ios_sheet_dismissal_test.dart`, and
modernization suites generate light/dark and constrained large-text fixtures
with `--dart-define=WRITE_UI_PREVIEWS=true`. Native VoiceOver and physical gesture feel remain
device checks.

## Upload presentation

Upload details use an opaque, edge-attached panel with continuous top corners.
In the iOS shell, `UploadPanelHost` places the panel inside the extended content
body. Its opaque background continues behind the native floating tab bar to the
bottom of the screen, eliminating the straight cutoff and exposed library strip.
The scrollable content reserves the tab bar's actual layout height, so file rows
and actions remain reachable above navigation. Tabs remain visible and usable
at every expansion. Android and standalone screens keep the scaffold sheet;
home-indicator clearance is inside the surface when navigation is absent.
The collapsed upload/Add controls hide while details are open and return when minimized; the queue is preserved.

One or two uploads open at the measured height of the header, actions and rows,
including wrapped text and errors. Larger queues retain the spacious opening
and lazy list. All sizes can expand to the large detent, scroll when constrained,
and minimize by dragging down, system Back or the semantic dismiss action.
Large text opens larger queues at the large detent. The iOS mobile-data action is
a leading-aligned Cupertino text button with a minimum 48-point target; Android
keeps its Material action.

This nonmodal composition follows Apple's [sheet customization guidance](https://developer.apple.com/videos/play/wwdc2021/10063/),
[layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout)
and [button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons).
The panel itself is Flutter; UIKit continues to own native tab rendering.
iOS uses a centered, semibold 17-point panel title and continuous top corners.
The surface moves as one layer during opening and dismissal, with no separate
footer transition. System Back, semantic dismissal and queue completion remove
the panel's local route history; reduced motion skips presentation movement.

Apple's [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout)
and [materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials)
place floating navigation above a continuous content layer. Glass stays on the
existing native tab bar; the upload content remains opaque and legible.

The upload presentation suite samples pixels around the navigation boundary over
a contrasting page, checks compact and expanded geometry, and covers dismissal
during animation. For native UIKit visual QA, use the isolated simulator entry
point `tools/ios_upload_preview.dart`; use `lib/main.dart` for physical devices.
The iOS 26.5 simulator was used to inspect the real UIKit tabs in light/dark,
resize the panel, and switch tabs while expanded. Native captures are generated
under `build/modernization/upload-native-*.png`. This is fixture-based simulator
verification, not a live transfer check on the physical iOS 27 device.

Files use 40-point thumbnails, unboxed rows, inset hairline dividers, quiet
completion marks, and thin progress lines aligned to the filename. Available
local photos render during upload with a bounded decode and a file-type fallback.
Preparation, upload, preview generation, waiting, cancellation and failure remain
explicit. Cancel/dismiss targets are 48 points; errors wrap and the retry action
keeps the controller's existing batch-retry behavior. Android retains Material
surfaces and interaction feedback.

The floating upload control pairs a small progress ring with a status and actual
completed-file count. It shares the Add control's neutral surface, without an
oversized cloud badge or a second edge-to-edge progress bar. The expanded view
shows total size; phase-weighted progress is not labeled as bytes transferred.
Both presentations derive their status from the same summary. Reduced motion
stops preparation/preview spinners and presentation transitions.

Generate populated transfer fixtures and exercise actions, header dragging,
semantic dismissal, both themes/platforms, and 320-point/200% text layouts:

```sh
flutter test --no-pub test/upload_presentation_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

The `upload-*` images under `build/modernization/` are Flutter fixtures with
portable fonts and navigation fallbacks. UIKit rendering, live transfers and
physical-device VoiceOver remain separate verification steps.

## Native item menus and selection

The iOS overflow button gives UIKit sole ownership of its tap region. An outer
Flutter tap recognizer must not intercept it and present the fallback overlay.
`UIMenu` requests a fresh state snapshot on every opening; View as and Sort by
remain native submenus with the current checkmark.

Selection follows the Files reference: a leading Select All capsule, centered
item count and a prominent blue checkmark to finish. The normal header uses a
104-point Select All capsule and a 44-point finish control; the bottom toolbar
is 48 points high with system-managed action grouping. At constrained widths or
large text the count gets its own centered line. Search remains available.
iOS list selection indicators sit at the leading edge with 12-point inner
padding. Selected rows use a quiet opaque fill and continuous 16-point corners,
with four-point vertical margins separating adjacent rows instead of creating a
solid rectangular block. Selection mode omits row dividers; unselected rows keep
the same geometry to avoid movement on tap. High contrast adds a visible outline,
and reduced motion removes the fill transition. Metadata can wrap fully at large
text sizes. Normal browsing rows and Android keep their existing treatment. Select All applies to eligible loaded items in the current
folder/search/filter scope, not unloaded library totals.

The shell replaces its tab bar with selection controls while selecting on iOS.
A native `UIToolbar` groups Share, Star, Move and Delete in one glass capsule,
with a separate overflow for Select All / Deselect All. Photos retains its
existing Share, Move and Delete actions. Empty selections disable batch actions;
Done restores the same tab state. Floating upload controls hide during selection.
Android retains its Material selection and navigation behavior.

The header overflow has a 34-point visual diameter inside a 44-point target;
the adjacent profile avatar stays 44 points. Native glass buttons use the same
size contract as their Flutter fallbacks.

On iOS, holding a loaded Drive file/folder, recent item or photo opens a real
`UIContextMenuInteraction`. UIKit owns the hold, targeted lift/dismissal preview,
menu placement, haptics and animation. Flutter reserves only the long-press
gesture for the platform view, leaving scrolling to its existing scroll view.
Selection mode and optimistic items bypass the native context interaction.

A source snapshot serves only the lift/dismissal animation. The source row
remains mounted across asynchronous bridge discovery, retaining its media and
layout. UIKit hides it only when a snapshot is available, then restores it at
the start of dismissal; action callbacks still wait for animation completion.
The content preview is separate: the existing scoped thumbnail loader supplies a local image/video
poster, and UIKit downsamples it to a bounded image. Preview proportions follow
the image and available device space; UIKit owns menu scrolling, preview
compression, continuous corners, spring transitions and dismissal.

PDF and common office-document originals up to 20 MB can load on hold through
the existing private Telegram media service (15-second transfer timeout), then
render through Quick Look thumbnailing. Unsupported, oversized or unavailable
content uses an honest icon/name/metadata card with the existing Open action.
No file bytes go through a backend fallback. Preview requests cancel on dismissal,
recycling or account change; late results cannot replace another item's preview.
The same thumbnail scheduler keeps downloads bounded and shared with visible tiles.

Tapping the native preview opens the existing item route; actions run after
dismissal and use the shared handlers, confirmations and move rules. Fresh menu
state includes Star / Unstar and Share / Revoke share. Missing bridges retain a
functional Cupertino context menu and accessible item actions.

In the iOS full-screen photo viewer, Share, Star, Info and Delete sit along the
bottom. The top overflow is native; Download and organization actions remain
there. Tap-to-hide controls, paging, zoom, the existing Hero transition and the
local-cache-first source resolution remain shared Flutter behavior. The current
Photos viewer embeds AVKit playback on iOS; see the Photos contract below. This
does not embed Apple's private Photos app.

References:
- [Apple toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)
- [UIKit toolbar grouping](https://developer.apple.com/documentation/uikit/customizing-your-app-s-navigation-bar)
- [Quick Look thumbnail generation](https://developer.apple.com/documentation/quicklookthumbnailing/qlthumbnailgenerator)
- [Apple context menus](https://developer.apple.com/design/human-interface-guidelines/context-menus)
- [Adding context menus in UIKit](https://developer.apple.com/documentation/uikit/adding-context-menus-in-your-app)
- [Context-menu preview and animation lifecycle](https://developer.apple.com/documentation/uikit/uicontextmenuinteractiondelegate)
- [Viewing photos on iPhone](https://support.apple.com/en-gb/guide/iphone/iph3d267610/ios)

`test/ios_item_interaction_test.dart` covers iOS selection controls at 320 points
and 200% text, disabled actions, fresh context state, account changes and Android
fallback behavior. `test/native/ItemContextMenuUITests.swift` exercises actual
UIKit interaction on the simulator: a sustained press, preview commit, Select,
Star/Unstar, scrolling, native overflow and disabled selection actions. See the
[iOS build guide](ios-build.md) for the isolated native fixture workflow.

Reference refinement verification (September 17, 2026): analyzer clean and 318
Flutter tests passed. Populated Flutter previews cover both themes and constrained
text layouts. The iOS 26.5 simulator exercised photo/PDF previews, unsupported-file
fallback, preview commit, fresh menu state, selection/overflow and disabled actions.
A separate menu drag check verifies that the PDF preview shrinks while the menu
stays open and Delete becomes reachable. Native screenshots were inspected.
Both simulator and unsigned production-device debug builds compiled; the device
build uses `lib/main.dart`. Physical iPhone gesture feel and VoiceOver were not
verified in this pass.

## Photo viewer

Photos now opens directly into a dated library with a collapsing Cupertino
header, visible All media / Photos / Videos categories, and a compact leading
Search button that expands into a field and X. The entire row is a retained
UIKit view: a system `UISegmentedControl` (its own iOS 26 track and glass
selection lens), sibling glass search/close surfaces in one glass container, and
a single UIKit spring that is retargeted from the on-screen state on every
toggle, so rapid open/close never restarts, reverses or skips the motion. The
categories fade out quickly as the field takes the row and back in once the
pill has room. The header (large title, overflow capsule, account) is the
shared `IosLargeTitleHeader` on the same `systemBackground` canvas as Drive.
Native accessibility settings select opaque surfaces or remove motion. Select
is in the three-dot menu with view options. Comfortable densities use stable featured
mosaics, with a persisted square-grid alternative. The viewer has coordinated
interactive dismissal to the current tile and embedded AVKit video controls.
See [Gallery layout](gallery-and-profile-refresh.md) and
[Photo viewer design](photo-viewer-design.md) for the current contracts.

See [Photo viewer design](photo-viewer-design.md) for the current nonmodal
inspector, thumbnail browsing, edge actions and grouped UIKit toolbar. This
supersedes the earlier modal photo-information composition.


## Search, upload sources and current browsing refinements

See [Mobile UX refinements](mobile-ux-refinements.md) for the native glass search
container, separate cancel target, keyboard lifecycle, Photos/Files source
chooser, gallery mosaic/highlights, metadata reconciliation and current checks.
Free Up Space uses the same compact navigation header as Settings. Its bottom
Check Again action owns rescanning; there is no duplicate refresh icon.

## Recovery, Starred and Shared browsing consistency

Archive, Locked and Trash present immediately when tapped on iOS. Their route
must not sweep the page and body text horizontally into the viewport. The
Cupertino route still owns interactive edge-back gestures, including cancelling
a swipe; Back returns to the retained Drive screen. Android keeps its Material
route transition. Verify entry frames with animations enabled, including empty
and loaded pages, rather than checking only the settled layout. Regression
coverage lives in `test/recovery_browser_test.dart`. The simulator-only
`tools/ios_recovery_preview.dart` uses the same page factory; enabling
`RECOVERY_RECORDING=true` cycles through all three empty and populated spaces
for a native frame recording. Production/device builds use `lib/main.dart`.

Archive, Locked and Trash use the Drive file/folder rows, 40-point thumbnails,
inset separators and platform symbols. Their iOS navigation is Cupertino, with
Select and Refresh in a native overflow menu; Delete All is a destructive Trash
menu action, behind the existing permanent-deletion confirmation. A hold opens
the shared native context interaction before selection. Item menus offer Open
for files, Unarchive/Unlock/Restore, Select and a separate destructive action.
Normal file taps open the existing viewer. Trashed folders expose recovery actions
rather than navigating into a deleted folder.

Selection uses the same Select All/count/Done header and native bottom action
controls as Drive. Recovery actions reflect the destination; empty selections
disable mutations. Loaded lists clear on account changes, and late reads or menu
callbacks cannot operate on the next account. Revision listeners refresh the
correct shelf. On the initial load, the body shows one loading state, then
reveals its introduction, loaded count and rows together. Lists build lazily
and preserve available media while refreshing.

Starred keeps its browsing composition and adds Drive's native hold-preview/menu
for both files and folders, in list and grid layouts. Select works from a hold or
the tab overflow. Its selection state participates in the shell's iOS tab-bar and
upload-control visibility, with the existing batch handlers and confirmations.

Shared retains link permission, active/revoked/expired status, views and downloads.
iOS list rows use Drive's 20-point gutters, thumbnail size, type hierarchy and
inset separators, with quiet link metrics below the item identity. Its introduction
is unboxed. Shared link holds and overflow controls use the native menu bridge:
Open, Copy link, Share link and confirmed Revoke link for an active link. Status
is resolved fresh at opening; revoked/expired links retain their detail destination.
Revocation uses a slashed-link icon in holds, overflow menus and the detail header,
with the existing destructive role and confirmation. Link actions remain
distinct from private file mutations.

At large text sizes, row thumbnails, selection indicators and overflow controls
move above the text so names and metadata can wrap across the content width.
The unavailable UIKit bridge uses a bounded Cupertino hold preview; source width
and grid height are retained so lifted rows cannot acquire infinite constraints.
Unavailable image previews use platform file symbols, never Google-style icons
on iOS. Android keeps its Material layout and interactions.

Trash preview requests use the same scoped media pipeline as Archive and Locked.
The backend owner-only media-ref endpoint must allow soft-deleted files while
retaining ownership checks and direct-download gating. Soft deletion keeps remote
media; purged or missing derivatives stay unavailable. See the backend's
[media architecture](https://github.com/ShekhawatPriya/TG-Cloud-Drive-BSDK/blob/main/docs/media-architecture.md).

## Account identity and public About content

The Account identity card retains the avatar/name/username header. A divider
separates a full-width connection information action from the quiet, selectable
Telegram ID below it. Missing usernames use “Telegram account” rather than
repeating the ID. The same information hierarchy applies to the Android sheet,
with Material actions and 48-point targets; iOS keeps Cupertino actions with
44-point minimums. Values wrap at large text sizes.

About TeleDrive orders content by purpose: app identity and installed version,
a compact live What’s New preview, an unboxed product explanation, maker identity
and social links, then grouped source and policy destinations. The header uses
a 72-point app mark and concrete Telegram-library copy. Avoid repeating source
navigation beside the update card or wrapping every explanatory section in a card.

What’s New uses the same title on both platforms, a short introduction, the newest
published release expanded, and earlier releases collapsed behind accessible
version/date headers. Latest published does not imply installed or available as
an update. Published headings define the categories; feature notes precede quieter
Release/Documentation/Build sections behind an explicit details control. Full
Changelog comparison links are deduplicated
and presented as separate actions. Link-only and empty notes have explicit copy;
never fill gaps with inferred features. Refresh failures retain loaded notes with
a retry notice. Loading, empty, and initial error states remain distinct.

Public GitHub history is fetched without a bundled token and follows pagination.
Notes and comparison links remain real published content. The canonical repository
is [ShekhawatPriya/TeleDrive](https://github.com/ShekhawatPriya/TeleDrive).

The editorial grouping and dated release hierarchy were informed by the published
[Linear changelog](https://linear.app/changelog), adapted to mobile reading and
TeleDrive’s existing Cupertino/Material controls. This is a composition reference,
not evidence of user testing. Preview fixtures cover a link-only release and a
categorized release with expanded history in both platforms/themes and large text.
At large text sizes, feature icons and release disclosure controls move above the
copy so explanatory text can use the full content width.

See [Gallery density and profile refresh](gallery-and-profile-refresh.md) for
current motion, layout and main Telegram photo refresh contracts.

## Browsing redesign: Drive, folders, Starred, Shared and recovery spaces

This section supersedes the earlier browsing descriptions above for the Drive
home, folder pages, Starred, Shared, Archive, Locked and Trash on iOS. Android is
unchanged. Primitives live in `lib/widgets/ios/ios_browse.dart` and
`lib/widgets/ios/ios_tab_header.dart`.

- **Canvas.** Browsing pages use `systemBackground` (white/black), as Files and
  Photos do; tiles use `secondarySystemBackground`. Settings-style pages keep
  the grouped background. System blue remains the only interface accent.
- **Header.** Each tab owns a `CupertinoSliverNavigationBar` large title (Drive,
  Starred, Shared) that collapses into the bar on scroll; the shell no longer
  draws a fixed iOS header. The overflow glass button and avatar stay pinned.
  Scoped search sits under the title and tucks away while browsing, but stays
  pinned while a query is shown. The bar is opaque because item rows host UIKit
  hold views a Flutter blur cannot sample; its hairline appears only once content
  scrolls beneath it. The large title shares the 20-point content gutter.
  Header platform views (search, glass back/overflow) set `claimsTouches` so a
  tap is not held until the scroll gesture resolves.
- **Overflow controls.** Header overflow is one 44-point native glass capsule
  with a 17-point medium `ellipsis`, as in the Files app (`IosHeaderActions`,
  beside a 40-point account avatar; the glass back button is also 44). Per-row
  overflow (files, folders, Shared and recovery rows) is a bare ellipsis with no
  capsule, `IosMoreButton(plain: true)` in a 48-point target, matching the
  Flutter ellipsis on Drive rows while keeping the native menu. A glass capsule
  appears on rows only where the control floats over a cover image (Shared grid).
- **Drive home.** Search, then Archive/Locked/Trash as three equal tiles (a
  tinted system-blue symbol over the secondary surface, name below; rows at large
  text), then Recents, Folders and Files with 22-point bold section titles. There
  is no "Your spaces" heading. Recents is an image-first rail: square thumbnails
  with captions on the page, 2.5 tiles visible, wider two-line tiles at large text
  and actions from the native hold. Folder tiles keep the pale-blue/black-outline
  treatment at 128 points, with names bottom-aligned above their metadata.
- **Files without a preview** use `IosFileGlyph`: the kind's system tint on a soft
  fill with a filled symbol (PDF red, documents blue, sheets green, video orange,
  audio purple, others grey) and the extension on larger tiles. Shared folders use
  the filled person-badge folder symbol without an extra link badge.
- **Folder pages** use the same large title with glass back and overflow, ancestor
  breadcrumbs only (the title names the current folder) and the Drive tiles.
- **Starred** drops the boxed introduction and reuses Drive's Folders tiles and
  Files rows/grid under the same titles.
- **Shared** groups links into Active and Expired or Revoked sections with counts.
  Rows use a 44-point thumbnail tile, the item identity, permission, and a status
  dot plus word (green active, orange expired, grey revoked) with view/download
  counts. Grid tiles put captions under the cover.
- **Archive, Locked and Trash** use the large title with glass back and overflow,
  an introduction carrying the same tinted symbol as the Drive tile, a quiet item
  count and the Drive rows. Empty and failed loads use the content-unavailable
  pattern (`IosContentUnavailable`); a failed load never shows a zero count.
- **Empty and search states** use a secondary symbol, a short title and one line
  of guidance; Drive search shows "No Results" with the query.

References: Apple's large-title navigation and ContentUnavailableView; Photos
Utilities and Reminders tiles; Uber's Suggestions tiles and Activity
(upcoming/past) grouping; Blinkit and App Store rails for compact, image-first
recents. These informed composition only; no brand styling is copied.

Verification: `test/ios_browse_design_test.dart` renders every surface populated
and empty in both themes, grid layouts, search with no results, collapse on
scroll, and 320 points at 200% text with high contrast (previews under
`build/modernization/ios-browse-*` with `--dart-define=WRITE_UI_PREVIEWS=true`).
`tools/ios_browse_preview.dart` runs the real shell with fixtures on a simulator.
With the current Xcode, `flutter build ios --simulator` fails at
`lipo -verify_arch`; generate config with `--config-only`, then build with
`xcodebuild ... -sdk iphonesimulator ARCHS=arm64 ONLY_ACTIVE_ARCH=YES`.
