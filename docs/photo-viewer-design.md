# Photo viewer interaction and platform design

## Library, navigation and dismissal

Photos opens directly into the dated library. The iOS tab owns its collapsing
Cupertino header and account entry. All media / Photos / Videos are visible in
one browsing row with a small leading search button; expanding search replaces
the categories, and X clears/exits back to the selected category. Select and view
options are in the three-dot menu. The category/search row uses a single UIKit
Liquid Glass hierarchy and reversible spring on supported iOS; its implementation
and older-host accessibility fallbacks are documented in Gallery layout.
The large cover carousel is removed. See [Gallery layout](gallery-and-profile-refresh.md)
for stable featured mosaics, square grids and density changes.

A `PhotoViewerSession` preserves the originating media filter, name query,
ordered IDs, current ID and Drive account generation. Refreshes reconcile by ID;
deleting the current item selects its remaining neighbor. The route remains
`/photos/view/:id`, with optional `filter` and `q` query parameters. In-app opens
also supply transient source-tile lookup/reveal callbacks; deep links need no
source tile. The retained library is visible through the nonopaque viewer route.
Direct links resolve missing media by ID and can return to Photos even without a
previous route. One stage owns the thumbnail-to-media transform, backdrop, chrome and dismissal;
the media view no longer runs a separate Hero flight.

An unzoomed downward drag follows the finger in both axes, scales uniformly and
reveals the library. A short release or upward reversal restores the viewer;
a downward release after 22% of viewport height, or a 900-point/second fling
after 32 points, completes dismissal. These thresholds are TeleDrive tuning,
not Apple's private constants. Return uses the current file's tile, revealing it
under the viewer first; an unavailable destination fades out. Back shares this
path. An open inspector consumes downward dragging and Back before the viewer.
Zoomed images retain pan/pinch ownership. Chrome, filmstrip and native playback
controls do not enter the viewer's dismiss gesture. Reduced motion removes
programmatic motion while retaining direct manipulation.

## Video and original-media lifecycle

On iOS, `teledrive/photo-video` embeds an `AVPlayerViewController` using proper
child-controller containment. It keeps native transport controls, scrubbing,
accessibility and system full-screen playback. It does not subclass AVKit or
match private control classes. Transport/control regions and `UIControl` touches
remain native; unclaimed media pans feed the same pager/stage used for photos.
The player is inset clear of the gallery header, filmstrip and action toolbar.
Android and missing-bridge hosts retain the Flutter player.

Only a settled active video starts, initially muted. The viewer retains position,
mute and explicit pause state for each visited file; page departure, covering
routes, backgrounding and audio interruptions pause playback. Headphone removal
pauses. Native events carry a session ID and obsolete events are ignored. No PiP
or background-playback entitlement is added. Silent previews do not take over
another app's audio session; explicit unmuting uses the playback audio session.

`PhotoMediaLoader` checks complete local originals before requesting metadata or
bytes. Its paths use the stable backend namespace, backend user, Telegram user,
file identity and revision. Originals are promoted atomically using DownloadCache.
Cancellation and account-generation checks guard every asynchronous handoff;
a failed direct Telegram transfer never falls back to a backend byte proxy.
Loading keeps a poster, reports preparation progress and offers Retry on failure.

The active image upgrades from its available preview to a bounded original
(maximum 4096-pixel decode edge), retaining relative zoom and pan. Adjacent images
can prepare derivatives, but cannot fetch originals. Original work is cancelled
on deactivation. Filmstrip scrubbing suspends expensive active-media preparation.

## Integrated information and actions

The photo viewer uses one nonmodal image-and-information surface. This supersedes
the modal photo-details layout described in earlier design records.

- Swipe horizontally on the photo to browse the loaded collection. The zoomable
  photo participates in the pager's gesture scope. The lazy thumbnail strip
  supports taps and scrubbing, keeps the current item centered, and exposes
  selection and loaded-item position to accessibility services.
- Selection follows the file ID across refreshes, reordering and starring.
  Removing an item clamps selection to a remaining neighbor.
- Swipe upward on the media or tap Info to reveal the same inspector. Drag the
  inspector farther to expand it, scroll its metadata, drag downward to collapse,
  or tap Info again. Android Back first closes the inspector.
- Direct drags have no forced middle snap. Slow releases stay where the user
  leaves them; flings use pixel-based clamping scroll inertia and stop at the
  physical boundaries. Info opens a consistent 55% inspection area, but it does
  not impose that position on a swipe or reversal.
- A persistent 44-point grip controls the inspector independently of metadata
  scroll position on both platforms. It can interrupt a fling, expand, or close
  the panel even after the metadata has scrolled. Assistive technology can
  increase/decrease it through the same control. Body scrolling retains Flutter's
  coordinated sheet/scroll handoff.
- Media keeps its full-screen layout, image aspect ratio and zoom/pan controller.
  Only a uniform paint transform fits the photo above the inspector. Lower
  letterboxing is consumed first; tall photos fit within the remaining space
  instead of being translated above the screen. Closing restores the original
  presentation without resetting zoom or pan. No axis is stretched independently.
- Info/back transitions use an interruptible, critically damped spring. Direct
  manipulation never animates toward an intermediate preset. Reduced motion
  removes programmatic spring/inertia; it does not delay finger tracking.
- The media has a repaint boundary and metadata is retained during extent-only
  updates, avoiding reconstruction of the inspector's contents every drag frame.
  Photo decode completion no longer initializes or scans the entire cache tree.
  Gallery date grouping is reused across density/selection rebuilds when files
  and the calendar day have not changed. Lazy grids and bounded thumbnails remain.
- iOS uses one UIKit `UIToolbar` through `teledrive/selection-toolbar` for Share,
  Star, Info and Delete. Flexible spaces separate the outer actions from the
  center group. All four SF Symbols use the same 22-point regular/medium symbol
  configuration, 48-point widths and 44-point native button heights. Selected items expose selected
  accessibility traits and filled symbols. This replaces the mixture of separate
  glass buttons and toolbar items that produced inconsistent icon sizes.
- Unsupported hosts and widget tests get functional opaque Cupertino fallbacks;
  those previews do not render UIKit Liquid Glass.
- Android uses Material actions on an opaque dark bottom bar, with the same
  shared callbacks, inspector, and selected-file state. The inspector has an
  Android drag handle and theme-aware opaque metadata groups.
- Metadata groups contain actual filename, format/MIME type, size, available
  dimensions/duration, containing folder, added/modified timestamps and relevant
  transfer status. Drive dates are not claimed to be EXIF capture dates. There
  are no invented camera, lens, location, Siri, image-search or editing actions.
- The inspector reserves bottom scroll clearance for persistent actions and the
  safe area. Text can wrap at 200%; thumbnail targets are 44 points and toolbar
  targets are 48 points on Android and at least 44 points on iOS. Hidden chrome is removed from pointer and semantics
  interaction. Existing share/delete confirmations remain authoritative.

## References

- [Apple: View photos and videos](https://support.apple.com/en-gb/guide/iphone/iph3d267610/ios)
- [Apple: See photo and video information](https://support.apple.com/guide/iphone/see-photo-and-video-information-iph0edb9c18f/ios)
- [Samsung: Check Gallery photo dates and details](https://www.samsung.com/uk/support/mobile-devices/how-to-check-the-date-and-time-in-the-samsung-gallery-app/)
- [Apple: UIImageView](https://developer.apple.com/documentation/UIKit/UIImageView)
  and [Android: Customize an image](https://developer.android.com/develop/ui/compose/graphics/images/customize):
  fit uniformly while retaining the source aspect ratio; independently filling
  both axes distorts photos. Test fixture preparation must obey this too.
- [Apple: SF Symbols](https://developer.apple.com/sf-symbols/): use the system's
  symbol family and consistent weights/scales rather than mixing drawn icons.
- [Android: Partial bottom sheet](https://developer.android.com/develop/ui/compose/components/bottom-sheets-partial):
  partially reveal details, then allow expansion and downward dismissal.
- [Flutter: DraggableScrollableSheet](https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html):
  share its controller with the metadata scroll view for resize-to-scroll handoff;
  programmatic changes do not automatically follow user-drag snap rules.

These sources inform the interaction model; the Info opening height and spring tuning are
TeleDrive implementation choices, not claims about Apple's private Photos physics.

## Verification

`test/photo_viewer_interaction_test.dart` covers actual photo paging, swipe-up
inspection, expansion, reversal, thumbnail scrubbing, identity reconciliation,
landscape image/panel adjacency (including rendered pixels), portrait states,
free-position releases, rapid reversals, fling interruption and grip collapse
after scrolling metadata,
both platforms/themes, and 320-point/200% text with reduced motion/high contrast.

Generate and inspect populated fixtures:

```sh
flutter test --no-pub test/photo_viewer_interaction_test.dart --dart-define=WRITE_UI_PREVIEWS=true
flutter test --no-pub test/modernization_ui_test.dart test/navigation_shell_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

The `viewer-*.png` files in `build/modernization/` are Flutter fixture renders.
Portrait, square and extreme-aspect test inputs crop the licensed source photo
without stretching it. Extreme-aspect inputs are geometry tests, not product
screenshots. No fixture is imported by production code. Flutter widget renders
cannot establish pixel-perfect equivalence with Apple's Photos. Native rendering
is checked separately in the simulator walkthrough below.


## Native toolbar walkthrough

On a simulator, build the isolated local fixture and run its XCTest walkthrough:

```sh
mkdir -p build/modernization
ffmpeg -f lavfi -i 'testsrc2=size=960x540:rate=30' -f lavfi -i 'sine=frequency=440:sample_rate=44100' -t 20 -c:v libx264 -pix_fmt yuv420p -c:a aac -filter:a 'volume=0.1' -y build/modernization/photos-native-fixture.mp4
flutter build ios --simulator --debug --no-pub -t tools/ios_photo_viewer_preview.dart --dart-define="PHOTO_PREVIEW_PATH=$PWD/test/fixtures/design/alpine.jpg" --dart-define="VIDEO_PREVIEW_PATH=$PWD/build/modernization/photos-native-fixture.mp4"
xcrun simctl install <simulator-uuid> build/ios/iphonesimulator/Runner.app
ruby scripts/test_ios_photo_viewer.rb <simulator-uuid>
```

The fixture uses the real pager, inspector and toolbar, with local-only action
callbacks. XCTest checks the fixture marker before interaction, verifies native
buttons and minimum target sizes, toggles star/Info, opens details by swipe, and
captures UIKit screenshots. The native copy-sharing walkthrough opens the OS
share sheet with a local original without choosing a recipient. Restore `-t lib/main.dart` for production builds.
Physical-device frame pacing and VoiceOver/TalkBack still require device review.

If the local Flutter simulator cache contains only ARM64, run the fixture build
with `--config-only`, then compile it using an explicit simulator destination:

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,id=<simulator-uuid>' -derivedDataPath build/photos-simulator ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO
xcrun simctl install <simulator-uuid> build/photos-simulator/Build/Products/Debug-iphonesimulator/Runner.app
ruby scripts/test_ios_photo_viewer.rb <simulator-uuid>
```


Historical verification before the library/dismissal/AVKit refinement: Flutter analysis and the full widget/unit suite passed;
populated viewer previews were inspected in both platform treatments, including
large text. The iOS 26.5 simulator walkthrough passed native action callbacks,
selected-state updates, minimum button sizes, and swipe/Info inspection. The
production iOS debug target compiled without signing, and Android debug APK
compilation passed. These fixture checks are separate from physical-device installation and gesture review.

Local validation used Flutter 3.44.0/Dart 3.12.0; CI pins Flutter 3.44.1. Android
used Android Studio's bundled JDK 21 with the project's existing Java target.
An SDK-mismatched generated hooks cache was rebuilt for the Android build;
no dependency or SDK configuration was changed. Device frame pacing, independent
accessibility-service interaction and CI's exact Flutter patch remain separate
checks.


## Copy and link sharing

See [Sharing files and folders](sharing.md). The viewer, gallery selections and
Drive actions use the same copy-or-link flow; photo dimensions and image-editing
state are not changed by sharing.

## Refinement verification

Behavioral coverage is in `test/photos_refinement_test.dart`,
`test/photo_media_loader_test.dart` and the existing viewer, metadata, thumbnail,
account and navigation suites. It covers scoped collections, identity changes,
dismiss/cancel/reversal, zoom/inspector precedence, native event isolation,
cancelled video preparation, complete-file caching and mosaic/selection geometry.
The simulator fixture now includes a real gallery-to-viewer route and a local
video. Run it with both `PHOTO_PREVIEW_PATH` and `VIDEO_PREVIEW_PATH`.
Physical-device frame timing, VoiceOver and audio-route/interruption behavior
must be reported separately from widget and simulator verification.

Additional implementation references:
- [Apple: embedded AVKit playback](https://developer.apple.com/documentation/avkit/playing-video-content-in-a-standard-user-interface)
- [Apple: continuously interactive transitions](https://developer.apple.com/videos/play/wwdc2024/10145/)
- [Flutter: iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views)

Validation for the current refinement uses Flutter 3.44.1 / Dart 3.12.1.
Analyzer, full Flutter regressions, and populated viewer/library previews are
checked independently from native compilation and simulator XCTest. The local
simulator engine contains ARM64 only; its native build uses an explicit ARM64
Xcode destination when Flutter's universal simulator wrapper requests x86_64.
Android validation uses JDK 17. Production builds use `-t lib/main.dart`.

October 6, 2026 local verification: analysis and all 573 Flutter tests passed.
Populated library/viewer previews were generated and inspected, including dark
appearance and the 320-point / 200% text library. Android debug APK compilation
passed with JDK 17; the production iOS debug device target compiled without
signing. The iOS 26.5 simulator passed toolbar/inspector/sharing walkthroughs and
the final native transport check: cancel/complete dismissal, muted autoplay,
pause, scrubbing, full-screen return and repeated reopening. The latter checks
use AVKit control identifiers and advancing elapsed time, avoiding assumptions
about transient OS accessibility labels. Physical-iPhone frame pacing, VoiceOver
and audio-route/interruption interaction remain unverified. No live account or
file mutations were used for fixture validation.
