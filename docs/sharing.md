# Sharing files and folders

All file Share actions, including the photo viewer, gallery selection, Drive and
file context menus, use the same choice:

- **Share a copy** prepares the original file(s) and opens the OS share sheet.
- **Create link** retains the existing public-link creation, confirmation,
  permissions, result and revocation flow.

Folder-only and mixed file/folder selections offer **Create link** only. Copy
sharing never silently omits selected folders and never creates a ZIP or invents
recursive file selection. Existing links do not remove the Share action; Revoke
share remains a separate action for an already-shared item.

## Copies and progress

`FileCopyShareService` prepares files serially to bound transfer/memory pressure.
It uses the existing original-file access path and account/revision-scoped
caches. Client-managed originals use `TelegramMediaAccessService`; unsupported
or unauthorized direct transfers fail closed. Legacy HTTP originals retain the
existing scoped `DownloadCache` path. The UI does not perform network/native
transfers itself.

Cached originals open the OS share sheet without flashing a progress panel.
Preparation lasting more than 200ms shows an adaptive opaque sheet with the
current filename, file position, byte progress, Cancel, and recoverable errors
with Try again. Native byte updates are coalesced to at most about ten progress
refreshes per second, with immediate file/completion transitions. Unknown byte
totals remain indeterminate; no estimated time or fictional progress is shown.

Only complete nonempty originals are handed off. Available file-size metadata
is validated. No preview or thumbnail is substituted. Files keep their MIME
identity and original names, with safe filename characters and numbered suffixes
for duplicate names. The share plugin ignores filename overrides for existing paths. Preparation
therefore stages the original under its real display name in a scoped cache,
streaming bytes to disk with cancellation and bounded memory. Completed staging
is reused on later shares; partial writes are never exported.

The iOS recipient panel is `UIActivityViewController`; Android uses the system
Sharesheet via the existing `share_plus` plugin, including multi-file sharing.
There is no app-built imitation of the recipient picker or custom Android 17
recipient layout. The installed OS owns that presentation. Flutter sheets finish
dismissing before presenting the next sheet, and an iPad popover origin is supplied. Viewer UIKit controls and the
iOS shell tab bar are removed while the flow is active so native glass does not
composite through a Flutter modal; they are restored when sharing closes.

## Cancellation and identity

A single share flow is active at a time. Cancel, sheet dismissal, and an account
change prevent a late native share handoff. Active downloads receive cancellation;
completed cached files can be reused on a later attempt. A cancelled batch never
shares a partially prepared subset. Backend/user/Telegram identity and token are
captured before the chooser, and switching away and back still invalidates it.

Link creation rechecks the originating account after public-link confirmation
and after creation. A stale result cannot be copied or passed to the OS share
sheet. Existing server-side creation/revocation and confirmations are retained.

## Verification

- `test/share_copy_test.dart`: filenames/MIME, multiple originals, incomplete
  downloads, cancellation/late success, account changes, retry, mixed folder
  selections, link request kinds and confirmation boundaries. Fixtures cover
  iOS/Android, light/dark and 320-point/200% text.
- `test/telegram_thumbnail_cancellation_test.dart`: transfer-ID cancellation,
  real bridge-event byte progress, and subscription cleanup after completion.
- `test/photo_viewer_interaction_test.dart`: free dragging, reversal, zoom/pan
  preservation and grip interaction with scrolled metadata.
- `test/native/PhotoViewerUITests.swift`: native iOS copy chooser and OS share
  panel using a local fixture. It does not send files to a recipient.

Generate visual fixtures with:

```sh
flutter test --no-pub test/share_copy_test.dart test/photo_viewer_interaction_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

The fixtures simulate downloads and errors without a live account. Actual large
Telegram downloads, receiving-app behavior and physical-device frame pacing
remain separate device checks.

## Platform references

- [Apple progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators):
  clear progress, actual known totals and cancellation for interruptible work.
- [Android sharing](https://developer.android.com/training/sharing/send): use the
  system Sharesheet, accurate MIME types and multiple-file intents.
- [share_plus](https://pub.dev/packages/share_plus): native share APIs,
  file-name overrides and the iPad popover anchor.
