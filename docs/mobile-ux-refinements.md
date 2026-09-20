# Mobile UX refinements

## Interaction contracts

- **Upload:** iOS Add to Drive says Upload, then presents a UIKit action sheet
  offering Upload from Photos and Upload from Files. The installed image_picker
  plugin opens the system multi-media picker without requesting full-library
  metadata access; file_picker opens the document browser. Android exposes
  Upload Photos and Upload File as separate native picker sources. Camera,
  upload limits, identity checks, confirmations and direct-transfer code remain
  shared. A missing source bridge has a Cupertino fallback.
- **Root folders:** keyboard insets used to remove Home's Add widget from the
  tree while its folder editor awaited a result. The unmounted-context check
  then discarded confirmation. Visibility now preserves that widget's state
  while hiding it. Errors are visible, and successful folder promotion removes
  the temporary metadata entry. There is no folder-count cap.
- **Metadata:** share and star changes patch folder pages, global metadata,
  media, starred, resolved/search and recent representations. Star responses
  change only the star flag; failure rolls back only that flag, retaining
  concurrent shares. Single-link revocation reconciles affected item flags with
  bounded reads because another link may still grant access. Shared snapshot
  files receive immediate indicators when a folder link is created.
- **Dates:** `createdAt` is the immutable upload/creation timestamp used for
  gallery order, date groups and browsing captions. `modifiedAt` maps the
  backend's `updated_at` record revision, which includes metadata changes and
  remains available to caches. It must not be used as a capture/upload date.
  Missing API dates remain unknown rather than being synthesized as now. No
  EXIF capture date is invented; the backend schema and timestamps are intact.
- **Folder cards:** iOS uses 40-point symbols / 18-point names in 156-point
  cards, pale blue in light appearance and outlined black in dark appearance.
  Android uses 44-point symbols / 20-point names in 176-point tonal cards.
  Both grow with text and use rows at large text sizes. Shared folder symbols,
  star/link markers and freshly resolved action menus reflect the same state.
- **Gallery:** chronological, lazy justified rows use the supplied image
  dimensions. Row widths/heights vary with aspect ratio and available width.
  Density controls target row height; unknown dimensions use a neutral ratio.
  Image decoding and transfer scheduling remain bounded. A session-stable sample
  of up to five actual photos forms a swipeable highlight carousel; the newest
  photo is not chosen as the initial highlight when alternatives exist. There
  is no ranking, inferred memory or fabricated recommendation. iOS and Android
  both expose star status without covering video duration or selection controls.
- **Share contents:** the parent navigation target, current folder and path have
  their own header row. Item icons, names and metadata share a consistent inset.
  File sizes are human-readable; the containing path is separate from the name.
  iOS uses person.crop.circle.badge.minus for revocation, distinct from Delete.
- **Search:** the keyboard Search action submits immediately and resigns focus
  while preserving the query. The independent X clears the query and exits.
  Clear inside the field keeps editing. UIKit owns the iOS text responder and
  two UIGlassEffect surfaces within a UIGlassContainerEffect. Their resting gap
  exceeds the container's merge threshold; an interruptible spring joins/splits
  their frames. Reduce Motion removes movement; Reduce Transparency and increased
  contrast use opaque surfaces. Older hosts/widget tests use an explicit Flutter
  fallback. Android uses opaque Material pills and a reversible size transition,
  with no focused outline inherited from form fields. Navigation, tab changes,
  outside taps and app inactivity dismiss the Flutter and native responders.
- **Account:** iOS uses a routed Cupertino page with Back/edge swipe, no X or
  draggable sheet. Subpages push above Account and return to it. The expanded
  switcher includes saved profile avatars. Android Account is unchanged.
  Free Up Space uses Settings' compact navigation hierarchy; Check Again remains
  in the footer without a duplicate refresh icon. Android Settings category
  badges match Account's existing Material outline icon treatment.
- **Selection:** folder selection headers size to their actual content, including
  wrapped Android actions, instead of a fixed 64-point app-bar constraint.

## Primary references and how they were applied

- [Apple UIKit and Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/284/):
  native shared glass containers and overlapping-to-separated frame animation.
- [UIGlassContainerEffect](https://developer.apple.com/documentation/uikit/uiglasscontainereffect)
  and [spacing](https://developer.apple.com/documentation/uikit/uiglasscontainereffect/spacing):
  actual material fusion, not an animated Flutter blur simulation.
- [Apple search fields](https://developer.apple.com/design/human-interface-guidelines/search-fields)
  and [PHPickerViewController](https://developer.apple.com/documentation/photosui/phpickerviewcontroller):
  recognizable search/clear behavior and system-owned photo selection. The
  separate X presentation is the requested application adaptation.
- [Android photo picker](https://developer.android.com/training/data-storage/shared/photo-picker)
  and [Material search](https://developer.android.com/develop/ui/compose/components/search-bar):
  separate visual-media selection, opaque search surfaces and keyboard submission.
- [Google Photos design](https://blog.google/products-and-platforms/products/photos/redesigned-google-photos/)
  and [organizing Photos](https://support.google.com/photos/answer/14169846):
  content-first browsing, less space between thumbnails and a top carousel.
  The justified-row algorithm is TeleDrive's adaptation; Google does not publish
  the proprietary mobile layout/ranking algorithm in these references.

## Verification

Regression suites include `item_metadata_regression_test.dart`,
`drive_search_dismissal_test.dart`, `navigation_shell_test.dart`,
`platform_folder_ui_test.dart`, `share_contents_test.dart`, and the existing
account/isolation/native-menu/media tests. The root test opens and submits the
real folder editor repeatedly while changing keyboard insets on both platforms.
Photo layout tests check aspect ratios, width bounds, order and lazy rendering.
Account tests navigate Settings, Telegram Drive, Free Up Space and My Data and
verify that Account remains underneath. Sharing's Windows fixture uses host-native
paths so XFile's name behavior matches the host; production copy logic is intact.

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub test/modernization_ui_test.dart test/navigation_shell_test.dart test/platform_folder_ui_test.dart test/share_contents_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
flutter build apk --debug --no-pub
```

Previews under `build/modernization/` use isolated data and portable fonts. They
cover both themes/platforms, 320-point widths, 200% text, increased contrast and
reduced motion. The search previews on Windows exercise the Flutter fallback,
not UIKit glass. Inspect the PNGs in addition to passing assertions.

Native search and account QA uses `tools/ios_design_preview.dart` with
`test/native/SearchInteractionUITests.swift`, following [iOS build](ios-build.md).
On macOS, compile with Xcode 26+ and inspect the spring forward, reversed halfway,
keyboard Search, Cancel, tab/route changes, VoiceOver, Reduce Motion and Reduce
Transparency. These native checks cannot run on the Windows development host.
Use `-t lib/main.dart` for device/production runs. No live account/file mutations,
backend deployment, release signing, publishing or app-data clearing are part of
fixture verification.


September 20, 2026 verification on Windows: static analysis was clean; the full
450-test suite passed with preview generation enabled; Android debug APK
compilation passed. Populated folder, gallery, search, share, Account/Settings,
Free Up Space and enlarged-text selection previews were inspected. UIKit search
and source selection remain source-reviewed and require the native checks above.
