# Gallery density and profile refresh

## Photos layout and motion

Date groups keep chronological order. Lazy per-file sliver geometry replaces
variable-height row lists, giving the scroll view an exact extent. Geometry is
cached by section, width and density. Known media proportions inform crops;
extreme ratios are bounded and missing dimensions use a square baseline. A
repeatable identity-seeded rhythm gives multiple interior photos or videos more
space at comfortable densities. Final incomplete rows are capped rather than
choosing the final item as a highlight. Tiles retain a 44-point minimum side.
Compact densities prioritise scanning. Pagination does not reshuffle earlier
complete rows or regenerate highlight choices on selection changes.

One-finger scrolling uses platform physics: bouncing on iOS and clamping on
Android. Pinching observes two pointers without putting ordinary vertical drags
into a competing scale gesture arena. Finger movement changes paint scale
immediately, with a bounded continuous density and an interruptible settling
spring. New density geometry is anchored to a visible file before layout;
a short 140 ms viewport blend handles row topology changes. It captures one
logical-resolution viewport, never the whole library, and releases that image
when the blend ends. Thumbnail widgets stay lazy and retain their identity.
Ordinary scrolling can resume without waiting for the density transition.
Reduced motion removes automatic spring/blend effects while retaining direct
pinch feedback. No native Photos implementation or private physics is claimed.

The direction follows Apple's [Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/)
(responsive, interruptible direct manipulation), Google's
[Photos redesign](https://blog.google/products-and-platforms/products/photos/redesigned-google-photos/)
(larger thumbnails and a tighter media-first library), and Android's
[animation guidance](https://developer.android.com/develop/ui/compose/animation/customize)
for spring continuity. Timings and geometry are TeleDrive choices.

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

Generate previews using the commands in [Design workflow](design-workflow.md).
Inspect the `account-refined-*` and `gallery-*` frames in `build/modernization/`.
These portable Flutter renders do not establish physical-device frame pacing,
VoiceOver/TalkBack behaviour, or exact UIKit/Google Photos parity.
