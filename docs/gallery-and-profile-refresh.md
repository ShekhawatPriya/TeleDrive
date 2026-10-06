# Gallery density and profile refresh

## Photos layout and motion

Photos is library-first on both platforms; the cover carousel is removed.
iOS uses its own collapsing Cupertino header. All media / Photos / Videos remain
visible in the primary browsing row, alongside a small leading Search button.
iOS hosts the entire browsing/search row in one retained UIKit platform view.
Its system category buttons, search surface and close surface use sibling
`UIGlassEffect` views in a single `UIGlassContainerEffect` on iOS 26 and later,
including iOS 27. The category lens is also a real glass effect, with native button accessibility
and touch tracking. It follows a horizontal drag directly and springs to the
chosen category on release; cancellation returns it to the previous selection.
This avoids the extra grey backing rendered by a stock `UISegmentedControl`. At large Dynamic Type sizes, a native horizontal
scroll view keeps full labels and 44-point targets reachable without shrinking
type. Android retains Material chips; hosts without the bridge retain the
functional Flutter selector. Select belongs in the three-dot menu with
Featured mosaic / Square grid and tile-size options, and remains available from
item context menus.

Search is secondary for this Telegram library. Tapping its button expands the
native search surface across the row, temporarily hiding the categories.
The close surface begins coincident with the search surface, then separates
through the shared glass container's fusion distance. Category glass
materializes/dematerializes in the same transition. The UIKit view and text
responder remain mounted throughout; there is no Flutter crossfade or clip
animation around the native control. A reversible `UIViewPropertyAnimator`
with `UISpringTimingParameters` owns the complete motion. Its 0.5-second settling
time and 0.86 damping are TeleDrive tuning, not claimed Apple-private constants. Keyboard Search dismisses the keyboard but retains the query and
exit control; Clear keeps editing. X clears the query, dismisses the keyboard,
and restores the category row with its prior selection. The shared Home search
keeps its existing behavior. Controls stay at least 44 points and skip the spring with Reduce Motion.
Reduce Transparency and increased contrast use the same native controls with
opaque system surfaces. Loaded counts live
after the library and never imply a whole-library total. iOS refresh
uses Cupertino scrolling behavior. Failed pagination retains visible items and
exposes Retry without repeatedly retrying on every scroll update.

Date groups keep chronological order. Comfortable mosaic densities mix justified
rows with deterministic three-item feature blocks. Source aspect ratios choose
wide-over-two and portrait-beside-two arrangements, with bounded cropping and a
neutral ratio for missing dimensions. Completed blocks stay stable as pages
append; changes to selection/star state do not rerank photos. Compact densities
prioritize scanning. Square grid is an explicit, persisted alternative. Every
tile keeps at least a 44-point side on supported widths. iOS tiles use restrained
four-point corners, compact status markers and separate video/selection badges.

The custom sliver caches exact geometry by section, width, style and density,
and builds only nearby tiles. Thumbnail decodes use bounded 320/640/960-pixel
buckets according to rendered size. Pinching observes two pointers without
competing with ordinary one-finger scrolling. Density changes retain a visible
file anchor and bounded viewport-only reflow blending. Reduced motion skips
settling/blending, retaining finger tracking. A horizontal selection drag can
extend or reverse a select/deselect range and autoscroll near viewport edges;
a vertical initial drag still scrolls normally.

The material and morphing implementation follows Apple's [UIKit Liquid Glass guidance](https://developer.apple.com/videos/play/wwdc2025/284/),
[glass container fusion](https://developer.apple.com/documentation/uikit/uiglasscontainereffect),
and [spring timing API](https://developer.apple.com/documentation/uikit/uispringtimingparameters).
The category grouping follows Apple's [segmented control guidance](https://developer.apple.com/design/human-interface-guidelines/segmented-controls);
the compact search priority is a TeleDrive product choice for Telegram media.
The direction follows Apple's [library display options](https://support.apple.com/guide/iphone/browse-your-photo-library-iph7d24753a5/ios),
[Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/)
and Google's [Photos redesign](https://blog.google/products-and-platforms/products/photos/redesigned-google-photos/).
Mosaic choices and spring tuning are TeleDrive behavior; these sources do not
publish Google's ranking algorithm or Apple's private gesture physics.

## Telegram main profile photo

The app refreshes authenticated identities on foreground return, after account
activation, when Account opens, and every two minutes while foregrounded.
Requests are coalesced per active/saved refresh pass. Background timers stop.
Secondary accounts are read sequentially with their own bearer token; refreshing
does not reconfigure the device TDLib session or replace active credentials.
Generation, token and identity checks reject stale results after account changes
or removal. Failure retains the last good snapshot.

`GET /me?refresh_telegram=true` requires the corresponding backend update. It
checks the current Telegram user's designated photo ID, including selecting an
older photo as the main one. Only a changed ID downloads avatar bytes. The ID
versions the photo URL, invalidating image caches without a new URL on every
poll. Confirmed removal clears both remote and local references. A failed photo
download preserves the previous avatar. Device photo files use backend/user/
Telegram/revision scope and remove authentication tokens from cache identity.
This endpoint changes profile metadata only; original file transfers remain
in the existing direct Telegram service.

## Verification

`test/profile_refresh_test.dart` covers coalescing, changed/removed avatars,
secondary credentials and stale account responses. `test/changelog_service_test.dart`
covers public unauthenticated pagination and malformed release data.
`test/modernization_ui_test.dart` includes populated Account/About/Gallery fixtures,
flings, pinch updates, retained tiles and scroll anchors on both platforms/themes.
`test/item_metadata_regression_test.dart` checks bounded chronological geometry.
The Photos header checks in `test/modernization_ui_test.dart` cover category
filtering, search disclosure, submit/clear/cancel, and restoring the category on
both platforms with animated and reduced-motion layouts. Run
`test/native/PhotosLibraryControlsUITests.swift` against the simulator-only
`tools/ios_photo_viewer_preview.dart` fixture to check UIKit autofocus, keyboard
submission, cancellation, repeated opening, native category buttons and lens tracking,
light/dark material and accessible-size horizontal selection. The bridge
regression in `test/photos_native_controls_test.dart` checks that filtering,
searching, cancelling and appearance changes retain one native host. See [iOS build](ios-build.md) for
the isolated XCTest runner; never install that fixture on a physical device.

Generate previews using the commands in [Design workflow](design-workflow.md).
Inspect the `account-refined-*` and `gallery-*` frames in `build/modernization/`.
These portable Flutter renders do not establish physical-device frame pacing,
VoiceOver/TalkBack behaviour, or exact UIKit/Google Photos parity.
