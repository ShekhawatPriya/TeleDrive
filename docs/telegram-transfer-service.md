# Telegram Transfer Service

Flutter UI code must not call TDLib directly. Uploads, downloads, progress, and
auth checks go through `lib/core/telegram`.

The Android bridge uses MethodChannel `teledrive/tdlib` plus EventChannel
`teledrive/tdlib/events`. It is backed by the official TDLib JSON-for-Java
artifact, `libtdjsonjava.so`, built from `tdlib/td` with the official Android
Dockerfile. If the artifact is missing for the current ABI, the bridge returns
`tdlib_unavailable`. Current builds fail closed and ask the user to reconnect on
a supported device; they do not upload file bytes through the backend.

TDLib local data is scoped by:

`tdlib/{api_base_url_hash}/{backend_user_id}/{telegram_user_id}/`

This avoids collisions when the same phone connects to multiple self-hosted
TeleDrive backends that may both have `user_id = 1`.

Direct mode also requires local `TELEGRAM_API_ID` and `TELEGRAM_API_HASH` in the
Flutter environment. The TDLib database encryption key is generated per scoped
directory and stored in secure storage.

Direct upload activation requires all of:

- backend bootstrap direct upload flag enabled
- local direct upload flag enabled
- TDLib native library available
- local TDLib authorization state ready
- TDLib `getMe.id` matches the active backend Telegram user id

Upload completion must wait for final TDLib send success. Temporary/local
message ids must never be committed to the backend. The transfer service rejects
missing or non-positive final message ids before `/file-complete` is called.

Derivative failures are non-fatal. If thumbnail, preview, or poster generation
fails, the original upload should still commit and derivative status should be
missing or failed.

Videos are local-cache-first for v1. The viewer should download/cache enough of
the file through TDLib and play from a local path instead of assuming HTTP range
streaming.

The bridge exposes local TDLib auth methods (`setPhoneNumber`, `checkCode`,
`checkPassword`) for the one-time local Telegram connection flow. Production UI
should call these only after the user explicitly opts in to direct media.

## Pending Commit Recovery

When TDLib reports final send success, Flutter writes a durable pending commit
record before calling `/client-uploads/{batch_id}/file-complete`. The record is
scoped by `{api_base_url_hash, backend_user_id, telegram_user_id}` and contains
the batch/file/local ids, original TDLib refs, optional derivative refs when
available, filename, MIME type, size, backend commit path, commit payload, and
retry timestamps.

On app bootstrap for the active account, pending records are retried without
reuploading to Telegram. A successful backend commit removes the record. A
failed retry keeps the record and increments its attempt count. Account
switching/removal is blocked while the active account has pending commit
records, because those records belong to a specific backend and Telegram
identity.

## Upload cancellation

Cancellation applies while backend file-start metadata, target resolution, or
native connection readiness is pending. Delayed callbacks must check the same
upload attempt before sending. Android and iOS order native send admission and
cancellation under their transfer lock, including uploads whose first TDLib
response has not yet supplied a file id. Cancelling an item also cancels its
active thumbnail and preview transfers.

Once TDLib returns a temporary message id, cancellation deletes that pending
message using `deleteMessages`, as supported by the pinned TDLib API. Its `ok`
response is only an acknowledgment. Permanent deletion updates are correlated
with the provisional and final message ids; cached deletions do not count. If
final success races the acknowledgment, the bridge checks the final message
before deciding whether it was deleted. An unavailable verification preserves
the known final reference after a bounded wait. Already observed final success
is never submitted for deletion.

An upload remains in the cancelling state, with account switching blocked, until
its worker settles. Backend cancellation and temporary-file deletion happen
after that point. If Telegram wins the race and reports final send success, the
original is saved to the pending commit queue and committed normally; optional
derivatives stop. Cancellation must not discard a successful original or cancel
the backend slot before its final outcome is known.

`test/upload_cancellation_test.dart` and
`test/telegram_upload_cancellation_test.dart` use delayed fixture metadata and
method-channel responses to exercise these boundaries. Native compilation and
real-device cancellation remain separate checks from the Flutter fixtures.

## Real-Device Smoke Test

Date: 2026-05-24

- Device: Samsung SM-X810
- Android: 16
- ABI: `arm64-v8a`
- TDLib artifact: `android/app/src/main/jniLibs/arm64-v8a/libtdjsonjava.so`
- Artifact SHA-256:
  `6e26e09d99dd7165477724dcbec215043046dcb484f7f67ac188db8621c6f8dc`
- Build: `flutter build apk --debug` succeeded
- Install: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
  succeeded
- Launch: `adb shell monkey -p com.example.flutter_m_fsdk 1` succeeded
- Native crash check: logcat showed no `FATAL EXCEPTION`,
  `UnsatisfiedLinkError`, or TDLib native-load crash during launch

The full real-device E2E verification was completed later on the same device.
See `docs/tdlib-real-device-verification.md` for the auth, direct upload,
`/media-ref` download/open, public share, fail-closed behavior, and restart
recovery results.

## Viewport thumbnail downloads

See [visible-first media loading](media-loading.md) for scheduling, cache scope,
retry, and cancellation contracts. Native thumbnail cancellation now covers
connection/message lookup as well as an active TDLib download. A cancelled
transfer ID must never be re-registered by late lookup completion. Cancelling
one waiter must preserve other consumers of the same native file.

## Resuming uploads after Wi-Fi waits

The upload controller listens to the current mobile-data preference, so both the
upload panel and Settings resume existing waiting items without reselecting files
or replacing transfer IDs. Connectivity checks re-read permission after awaiting
the platform; Wi-Fi or Ethernet satisfies Wi-Fi-only mode even if cellular is
also reported. Queue scheduling excludes IDs already reserved by an in-flight
worker, preventing repeated taps or concurrent wakeups from starting a duplicate
batch. The settings listener is removed on disposal.

`test/upload_network_resume_test.dart` exercises these boundaries with the real
upload controller and fixture connectivity/metadata requests. It does not perform
live Telegram transfers.


## Original-file sharing progress

`downloadToCache` accepts an optional byte-progress callback. It subscribes to
its generated transfer ID before starting the native download and removes the
subscription on completion, failure, timeout or cancellation. Existing callers
remain unchanged. `TelegramMediaAccessService` forwards this callback while
retaining authorization, identity, generation and cache-key checks.

Copy sharing requests the original variant and never falls back to a thumbnail,
preview, link, or backend transfer when direct access fails. Cancelling the
preparation sheet cancels the active request and prevents the native share sheet
from opening after a late completion. See [sharing](sharing.md).
