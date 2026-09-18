# Application modernization

## Product contracts

Preserve Telegram authentication and local TDLib sessions, account switching,
direct transfers and durable pending commits, gallery backup, file/folder
operations, preview, sharing/revocation, archive, locked items, trash/recovery,
storage management, updates and legal/project information. Existing API paths,
database history and secure-storage identities remain compatible.

## Design system

- Content comes first: neutral grouped surfaces, one blue action accent and
  semantic status colors. No wallpaper-dependent branding or decorative gradients.
- System typography on iOS and Android; clear headings, legible secondary text,
  scalable controls and a four-point spacing grid.
- One router-owned stack per primary destination. Compact devices have labeled
  bottom navigation; expanded layouts have a rail. Detail pages use platform back.
- Glass is limited to iOS navigation, with opaque accessibility fallbacks.
  Flutter translucency is an approximation, not native Liquid Glass.
- Minimum 48 logical-pixel actions, explicit semantic labels, keyboard focus,
  reduced-motion support and layouts that tolerate enlarged text.
- Search describes the current scope and real supported behavior. Loading,
  empty, error, retry and partial results must be distinguishable.

References reviewed September 16, 2026:

- https://developer.apple.com/wwdc26/guides/design/
- https://developer.apple.com/design/human-interface-guidelines/materials
- https://m3.material.io/foundations/layout/canonical-examples/overview

## Engineering workstreams

1. Shared theme, adaptive navigation, accessible components and onboarding.
2. Drive, photos, starred, shares, preview, account/settings and recovery surfaces.
3. Request lifecycle, account isolation, search race handling and refresh state.
4. Backend validation, worker lifecycle, resource cleanup and API regressions.
5. Flutter analysis/tests, backend tests, rendered UI checks and delivery audit.

## Evidence boundaries

Local fixtures are not live Telegram verification. Android/iOS device validation,
background transfers, native permission flows, signing, store submission and
production PostgreSQL/deployment need their respective environments. Never label
the whole application production-ready solely because local tests pass.

## Existing workspace changes

`docs/ios-build.md` was already modified before this work and is left intact.


## Delivered changes

| Area | Implementation |
| --- | --- |
| Navigation | Router-owned persistent tabs; adaptive bottom bar/rail; platform page transitions; tested detail routes and retained tab state. |
| Design system | Neutral light/dark/high-contrast surfaces, platform type, shared brand mark, scalable controls and reduced-motion loading treatment. |
| Welcome/sign-in | Focused introduction, progressive storage/privacy detail, scoped form autofill and disabled controls during requests. |
| Drive/folders/starred | Scoped search, paginated search controller, responsive grids, wrapping selection tools and retry states. |
| Photos | Lazy date-group sliver grids, adaptive columns, pull-to-refresh and bounded initial tile construction. |
| Storage/settings | Visible cloud/device sections, honest loading/error states, grouped settings with immediate presentation. |
| Preview/download | Shared Drive/Photos opening path, account checks across awaits and revision-scoped complete-file caching. |
| Account/state | Candidate login keeps active credentials intact; stale reads/mutations cannot overwrite reset account state; bulk delete stops at an account switch. |
| Sharing | Safe concurrent revocation rollback, modern native share API and matching responsive public HTML on the backend. |
| Backend | Retryable bounded workers, cancellation/resource cleanup, readiness endpoint, safe validation, pagination bounds, JWT validation and atomic folder rename/move validation. |
| Maintenance | Removed unreachable screens, redundant animation wrappers, unused font/color packages and 653 unused backend imports; indexed optimistic file reconciliation. |
| Delivery | CI checks, release credential guards on Android/iOS, required Android release signing and explicit production Compose readiness/configuration. |

The public routes, account/storage identifiers, Telegram transfer protocol,
existing migration history and installed Android application ID are retained.
Legal, project, update, backup, recovery and account screens inherit the shared
visual system; this does not imply every leaf screen received a new layout.

## Dependency decisions

Updated file_picker to 13.1, package_info_plus to 10.2 and share_plus to 13.3,
including their API migrations. Wakelock resolves to 1.7, compatible with the
verified Flutter 3.44.1 SDK; the newest release requires a newer SDK. Other
major-version upgrades are not automatically applied without compatibility proof.

Official maintainer references:

- https://pub.dev/packages/file_picker/changelog
- https://pub.dev/packages/package_info_plus/changelog
- https://pub.dev/packages/share_plus/changelog
- https://pub.dev/packages/wakelock_plus/changelog

## Reproduce checks

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter test test/modernization_ui_test.dart --no-pub --dart-define=WRITE_UI_PREVIEWS=true
flutter build apk --debug --no-pub
dart run scripts/verify_release_config.dart .env.example
```

Component previews are written to `build/modernization/`. They use fixture data
and a bundled portable test font. They are not screenshots from an iPhone.

Release assets must not contain GitHub tokens or backend credentials. The Android
release task requires the existing release keystore; it no longer silently accepts
a debug signing key. iOS release builds invoke the same client-config check before
Flutter's Xcode build phase. No private environment file or key was changed.

See the backend's `docs/production-modernization.md` before using production
Compose: `POSTGRES_PASSWORD` must match the existing database and `DATABASE_URL`.
Do not treat changing an environment variable as rotating an existing DB password.


## Verification recorded

- Flutter 3.44.1 / Dart 3.12.1: analyzer clean; 98 tests pass.
- Frontend tests include account races, credential isolation, cache identity,
  pagination, router/tab restoration, 320px layouts with 200% text, selection
  controls and a 1,000-photo lazy-render check.
- Backend: 140 tests pass using a dedicated SQLite fixture database; focused Ruff
  checks pass across the application and route/service imports.
- Light/dark component renders generated and visually inspected. Test fonts are
  portable substitutes for platform fonts.
- Android debug compilation verified after plugin migration; no release signed
  or published. Native plugin upgrades required clearing their stale build outputs.
- Samsung SM-S906E: updated debug APK installed preserving app data; the phone
  received HTTP 200 with `database_ok: true` through the USB backend connection.
  This verifies connectivity, not a completed Telegram login or every app screen.
  iOS compilation and the new Xcode release
  phase require macOS/Xcode verification; live Telegram, permissions, background
  execution and production PostgreSQL contention remain device/deployment gates.

The existing test suite deliberately exercises missing-plugin/navigation failures;
those diagnostic messages are expected in the corresponding passing tests.

## Local development on an Android phone

Connect the phone by USB, authorize USB debugging, and run from the frontend:

```powershell
.\scripts\connect-phone.ps1
```

The helper starts Docker/PostgreSQL and the local backend when needed, waits for
database health, establishes the USB connection, and opens the app. Add `-Install`
to install an already-built debug APK while preserving app data. Use `-DeviceId`
to select a particular connected phone.

USB forwarding does not depend on the Wi-Fi IP address. Keep the computer and
backend running; run the helper again after reconnecting the phone. The backend
still runs on the computer, not inside Android. For access independently of this
computer, deploy the backend with a stable HTTPS address configured in the app.

Connection follow-up checks: two focused resolver tests passed, Flutter analyzer
was clean, and the updated debug APK built and installed successfully. No live
Telegram authentication request was submitted as part of these checks.

## Startup work and performance

Returning sessions still validate the backend bootstrap and account identity
before leaving the splash route. Backend selection/pinning, Telegram readiness,
pending commits, feature flags and credential persistence retain their existing
contracts. There is no cached-data-first authentication shortcut.

The returning-session path skips the duplicate blocking profile-photo download.
The existing ProfileAvatar widget loads/caches the current URL asynchronously
and may briefly show initials. The saved local photo reference is retained;
explicit profile refresh continues to maintain the local fallback. Login and
account switching retain their existing cache behavior.

Local environment loading and package metadata lookup run concurrently.
Notification setup runs after Flutter's first frame. Initialization is shared
between concurrent callers, tracks the current lifecycle state and can retry a
failed attempt. Permission and notification calls still await initialization;
startup never requests notification permission.

Use profile mode on a physical device for timing. Debug JIT startup is not
representative of a production build. Separate time to the first Flutter frame
from time spent validating the session and reaching Drive. Network variability,
process/cache state and recording overhead affect individual runs; a small
sample is not a universal startup guarantee. Shared Dart changes apply to
Android and iOS, but iOS timing requires a physical iPhone and Xcode.

Regression coverage:
`flutter test --no-pub test/startup_auth_test.dart test/upload_notification_initialization_test.dart`

Reference: https://docs.flutter.dev/perf/ui-performance


## Folder sharing

Shared links retain the selected root's name and explicit file/folder kind on
Android and iOS. Share details browse the captured hierarchy and show file type,
size and relative path. The API supplies `primaryName`, `primaryKind` and
`parentPublicId`; filenames are never used to guess whether an item is a folder.

The public browser is served by the backend's `/s/{token}` route, not the marketing
website. It provides breadcrumbs, nested and empty folders, file metadata,
individual downloads and ZIP downloads of all or selected files/folders. ZIPs
retain relative paths. Folder links are snapshots of available files at creation;
subsequent additions require a new link. Oversized snapshots fail explicitly.
Public recipients use a verified server proxy; private mobile bytes remain direct
TDLib transfers. See the backend `docs/media-architecture.md` and
`docs/FRONTEND_API_CONTRACT.md` for availability and download limits.

Regression fixtures: `test/share_contents_test.dart` covers both platforms,
light/dark, 320-point widths, 200% text, nested navigation and explicit item kinds.
Generate screenshots with `--dart-define=WRITE_UI_PREVIEWS=true`.
