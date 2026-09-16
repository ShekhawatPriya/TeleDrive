# Platform refinement and hosted connection

Android is the primary audience. Shared task flows remain consistent, with
deliberate platform differences in controls, surfaces and feedback.

| Component | Android | iOS |
| --- | --- | --- |
| Create / rename folder | Spacious Material sheet, live folder preview, outlined field, Cancel/Create actions | Inset frosted sheet, Cupertino text editing, grouped field, full-width confirmation |
| File / folder actions | Compact identity header, tonal quick actions, grouped management and destructive actions | Folder summary, Share/Star shortcuts, compact management rows and separate destructive action |
| Navigation | Solid floating dock with tonal selection, ripple and labelled targets | Frosted dock, moving selection capsule, Cupertino symbols and press feedback |
| Search / typography | Material search field and platform typography | Cupertino search, large title, system font on device |
| Content | Opaque cards with the existing brand palette | Neutral grouped surfaces, blue accent, continuous folder-card corners |
| Move / confirmation | Keyboard-safe Material sheets and Material alerts | Inset material sheets and Cupertino confirmation alerts |

Glass is a Flutter rendering using bounded backdrop blur and layered surfaces,
not UIKit's native `UIGlassEffect`. Android incurs no backdrop-filter cost from
these components. High contrast uses opaque materials; reduced motion disables movement independently
while preserving translucency. Layouts retain large touch targets, text
scaling, keyboard avoidance, scroll access and desktop maximum widths.
Native iOS rendering, VoiceOver and device frame timing require an iPhone/Mac
check; Windows fixture screenshots are not native iOS execution evidence.

## Design references and application

- [Apple WWDC26: Platforms State of the Union](https://developer.apple.com/videos/play/wwdc2026/102/),
  iOS 27 refinements: readable diffusion, stronger separation, adaptable layouts.
- [Apple materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials):
  reserve glass for the floating functional layer and keep content legible.
- [Blinkit: Introducing Bolt](https://blinkit.com/blog/introducing-bolt/): reusable
  components and consistent journeys across platforms; applied through shared
  editor and sheet contracts rather than separate feature implementations.
- [Uber Design Platform](https://medium.com/uber-design/uber-design-platform-1ebff86c89e7):
  restrained foundations, consistent spacing/type and familiar patterns. Used as
  design principles, not a claim to reproduce Uber's private mobile components.
- [Android: translate platform designs](https://developer.android.com/design/ui/mobile/guides/foundations/translate-designs):
  preserve Android interaction conventions within a shared product identity.

## One backend across devices

`.env.local` now points to `https://teledrive.185.163.2.12.sslip.io/api`.
`BACKEND_PINNED=true` makes this the single destination, including on devices
with a saved old LAN address. An unreachable server stays unreachable rather
than silently connecting to another machine.

`BACKEND_IDENTITY=legacy-local` preserves the pre-migration namespace for local
TDLib data, encryption keys, pending commit queues and cached downloads. Network
URLs can change without discarding those local records. Use another identity
when connecting to a different database; this migration preserved account IDs.

The tracked `.env.example` contains public server settings. The release workflow
runs `scripts/configure_hosted_backend.dart` after restoring client credentials,
so an old `ENV_LOCAL` secret cannot reintroduce the LAN endpoint in future builds.
No release or remote GitHub secret was published/changed by this work.

For explicit local development, turn off the pin and remove API_BASE_URL from
your local environment; the original discovery flow remains available.

## Review

```powershell
flutter test test/platform_folder_ui_test.dart test/modernization_ui_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
flutter test test/hosted_backend_config_test.dart
```

The folder tests exercise create/rename/cancel, trimmed values, keyboard submit,
320px layouts and 200% text with a keyboard. Connection tests exercise HTTPS URL
normalization, preservation of local identity, stale override removal, and no
fallback when the pinned service becomes unreachable.

See the backend workspace's `docs/VPS-GUIDE.md` for server layout, SSH, backups,
recovery and migration evidence.

Validation on September 16, 2026: static analysis clean, full suite 145 tests
passed, 41 review previews generated, Android debug APK built and installed on
the connected Samsung SM-X810 without clearing app data. Its process launched;
the tablet was locked, so a visible on-device interaction walkthrough was not
completed. The APK was inspected to confirm the HTTPS server settings and
Cupertino font were packaged. Windows HTTPS connectivity was verified, but this
repository has no Windows desktop target; native Windows compilation is therefore
not available. Native iOS compilation was not performed on this Windows host.


## Follow-up: translucent navigation, login and item actions

The iOS navigation surface now uses 16–32% tint and 14px backdrop blur, with its
shadow clipped outside the material so it cannot darken the transparent center.
Sheets retain a denser material. This is still a Flutter glass rendition, not
UIKit system Liquid Glass or proof of iPhone GPU performance. The navigation
pixel test verifies that changing content behind the surface changes its rendered
color substantially; high contrast remains opaque, and Android has no blur.

The login screen now includes all three real states (phone, code, password),
platform-specific input, grouped iOS country/phone entry, autofill, accessible
errors and progress, a searchable country picker, back navigation and an adaptive
layout. Backend and TDLib authorization contracts are unchanged. Fixture tests
exercise the flow without sending Telegram codes, including dismissal during an
in-flight request and 320px/200% text with a keyboard.

The iOS item sheet now separates its identity/real metadata, Share/Star/download
shortcuts, management rows and destructive action. A dedicated action-contract
test activates each action at 200% text and verifies the returned ID. The top
more-menu now uses a Cupertino translucent presentation on iOS while retaining
its existing Material presentation on Android.

Research for this revision revisited Apple's [iOS 27 design update](https://developer.apple.com/videos/play/wwdc2026/102/),
[materials](https://developer.apple.com/design/human-interface-guidelines/materials),
[menus](https://developer.apple.com/design/human-interface-guidelines/menus) and
[entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data).
The implementation interprets the hierarchy and material principles; it does not
claim these custom layouts are Apple's standard system components.

Revision verification: 156 Flutter tests passed; static analysis clean. Refreshed
53 fixture previews, including all login states in both themes and platforms.
Android debug APK compiled. No live Telegram authentication was triggered.


## Live tablet login verification and navigation fix

On September 16, the connected Samsung SM-X810 completed backend code/password
verification and authenticated bootstrap successfully (HTTP 200). The user then
reported returning to the landing page despite the saved session being valid.

The API provider watched BackendResolver status notifications. Every connection
notification could recreate ApiClient, AuthRepository and AuthController while
GoRouter retained the previous AuthController. The fix watches the resolver's
notifier identity; requests still consult its current URL and readiness, without
replacing the authenticated services on status changes.

`test/auth_connection_lifetime_test.dart` failed before the fix and passes after
it, checking retained client/controller identity, credentials and account state.
The full suite passed 157 tests; static analysis was clean. The debug APK was
rebuilt, installed over the existing app without clearing data, and launched.
The user confirmed: the drive opens and files load with the existing session.
Server logs showed successful authenticated account, storage and media requests.
No second sign-in or sign-out was performed for the final verification.
