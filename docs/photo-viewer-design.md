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
- The inspector consumes the lower letterbox before moving the visible photo.
  Its opening position uses the decoded image's aspect ratio, with model
  dimensions as a fallback. Landscape images meet the inspector without a dead
  black gap; portrait images remain full width and move behind its upper edge.
- Direct drags track the finger. Button and media-drag settling use an
  interruptible, critically damped spring with release velocity. Reduced motion
  resolves those programmatic transitions immediately. Flutter owns sheet
  scrolling and snap physics.
- iOS places share/delete at the outside edges with a centered star/Info group.
  The group reuses the existing UIKit `teledrive/selection-toolbar` bridge with
  SF Symbols and filled selected-state symbols. Edge controls reuse
  `NativeGlassButton`. Unsupported hosts and widget tests get functional opaque
  fallbacks; those previews do not render UIKit Liquid Glass.
- Android uses Material actions on an opaque dark bottom bar, with the same
  shared callbacks, inspector, and selected-file state. The inspector has an
  Android drag handle and theme-aware opaque metadata groups.
- Metadata groups contain actual filename, format/MIME type, size, available
  dimensions/duration, containing folder, added/modified timestamps and relevant
  transfer status. Drive dates are not claimed to be EXIF capture dates. There
  are no invented camera, lens, location, Siri, image-search or editing actions.
- The inspector reserves bottom scroll clearance for persistent actions and the
  safe area. Text can wrap at 200%; thumbnail targets are 44 points and toolbar
  targets are 48 points. Hidden chrome is removed from pointer and semantics
  interaction. Existing share/delete confirmations remain authoritative.

## References

- [Apple: View photos and videos](https://support.apple.com/en-gb/guide/iphone/iph3d267610/ios)
- [Apple: See photo and video information](https://support.apple.com/guide/iphone/see-photo-and-video-information-iph0edb9c18f/ios)
- [Samsung: Check Gallery photo dates and details](https://www.samsung.com/uk/support/mobile-devices/how-to-check-the-date-and-time-in-the-samsung-gallery-app/)
- The six screenshots supplied for this change establish the requested iOS
  geometry and persistent toolbar composition. Samsung's guidance establishes
  the Android gesture convention; it does not provide pixel specifications.

## Verification

`test/photo_viewer_interaction_test.dart` covers actual photo paging, swipe-up
inspection, expansion, reversal, thumbnail scrubbing, identity reconciliation,
landscape image/panel adjacency (including rendered pixels), portrait states,
both platforms/themes, and 320-point/200% text with reduced motion/high contrast.

Generate and inspect populated fixtures:

```sh
flutter test --no-pub test/photo_viewer_interaction_test.dart --dart-define=WRITE_UI_PREVIEWS=true
flutter test --no-pub test/modernization_ui_test.dart test/navigation_shell_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

The `viewer-*.png` files in `build/modernization/` are Flutter fixture renders.
The portrait fixture crops the same licensed test photograph; neither fixture
is imported by production code. Native iPhone rendering, system-glass appearance,
VoiceOver/TalkBack and physical gesture feel require device review. Windows
widget renders cannot establish pixel-perfect equivalence with Apple's Photos.
