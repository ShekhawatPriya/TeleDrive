# iOS design

Reference: `/Users/sree/Code/PNL/Passwords`, including its Cupertino page structure
and UIKit glass-button platform view. Brand colors are app tokens, not an
Apple-mandated hex palette.

Apple references:
- [Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [UIKit's new design](https://developer.apple.com/videos/play/wwdc2025/284/)
- [UIButton menus](https://developer.apple.com/documentation/uikit/uibutton/menu)

## Native controls

`NativeTabBar` embeds UIKit's `UITabBar`, including SF Symbols, the system glass
selection lens and native touch handling. Flutter owns the existing tab routes;
UIKit sends selection events and receives updated index/appearance values.
Android retains its separate Flutter navigation.

`NativeGlassButton` uses `UIButton.Configuration.glass()` on supported iOS.
Overflow buttons use a real `UIMenu` with `UIAction` entries. An uncached deferred
menu requests a fresh Dart snapshot each time it opens, preserving callbacks,
checkmarks, subtitles and destructive state. Layout and sorting are submenus.
Missing native bridges fall back to working Flutter controls for tests/old hosts.

## Account destinations

The iOS account route uses `showCupertinoSheet` and a scroll-controlled `IosPage`.
The page paints its own theme-aware background, avoiding a fixed dark sheet
background after switching to Light. Choosing an account destination dismisses
the sheet before navigating.

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
17-point heading and explicit close control. Labels carry the choice; redundant
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
