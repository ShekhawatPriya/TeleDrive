# Photo viewer interaction and platform design

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
flutter build ios --simulator --debug --no-pub -t tools/ios_photo_viewer_preview.dart --dart-define="PHOTO_PREVIEW_PATH=$PWD/test/fixtures/design/alpine.jpg"
xcrun simctl install <simulator-uuid> build/ios/iphonesimulator/Runner.app
ruby scripts/test_ios_photo_viewer.rb <simulator-uuid>
```

The fixture uses the real pager, inspector and toolbar, with local-only action
callbacks. XCTest checks the fixture marker before interaction, verifies native
buttons and minimum target sizes, toggles star/Info, opens details by swipe, and
captures UIKit screenshots. The native copy-sharing walkthrough opens the OS
share sheet with a local original without choosing a recipient. Restore `-t lib/main.dart` for production builds.
Physical-device frame pacing and VoiceOver/TalkBack still require device review.

Verified for this revision: Flutter analysis and the full widget/unit suite passed;
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
