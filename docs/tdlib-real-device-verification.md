# TDLib Real-Device Verification

Date: 2026-05-24

## Environment

- Device: Samsung `SM-X810`
- Android: `16`
- ABI: `arm64-v8a`
- TDLib version reported by logs: `1.8.64`
- TDLib commit reported by logs:
  `e0943d068ce90b5010f1aea946e6901e25b43bf6`
- Vendored arm64 artifact SHA-256:
  `6e26e09d99dd7165477724dcbec215043046dcb484f7f67ac188db8621c6f8dc`
- Backend port: `8001`
- Backend base URL: `http://192.168.1.5:8001`
- Flutter API base URL: `http://192.168.1.5:8001/api`

Backend flags used:

- `CLIENT_DIRECT_UPLOADS_ENABLED=true`
- `CLIENT_DIRECT_DOWNLOADS_ENABLED=true`
- `CLIENT_DERIVATIVE_GENERATION_ENABLED=true`
- `LEGACY_BACKEND_UPLOADS_ENABLED=true`
- `GALLERY_BACKUP_ENABLED=true`
- `PUBLIC_SHARE_PROXY_ENABLED=true`
- `PUBLIC_BASE_URL=http://192.168.1.5:8001`
- `PUBLIC_SHARE_BASE_URL=http://192.168.1.5:8001`

Flutter flags used:

- `DIRECT_TELEGRAM_UPLOAD_ENABLED=true`
- `DIRECT_TELEGRAM_DOWNLOAD_ENABLED=true`
- `CLIENT_DERIVATIVE_GENERATION_ENABLED=true`
- `LEGACY_BACKEND_UPLOAD_FALLBACK_ENABLED=true`
- `GALLERY_BACKUP_ENABLED=true`
- `MAX_CONCURRENT_TELEGRAM_UPLOADS=2`
- `MAX_CONCURRENT_DERIVATIVE_TASKS=2`
- `MAX_CONCURRENT_GALLERY_UPLOADS=1`
- Telegram API credentials were configured locally for the real-device test and
  are intentionally not recorded in this document.

## Result Summary

The real-device TDLib E2E path passed:

`TDLib auth -> direct upload -> backend metadata commit -> media-ref -> TDLib download -> local open -> restart recovery`

The active TDLib user matched the backend Telegram user:

- TDLib `getMe.id`: `5009626431`
- Backend `telegramUserId`: `5009626431`
- TDLib username observed: `Sreejan07`

## Auth Verification

The app launched on the real arm64 Android device without a native TDLib load
crash. The Device Telegram Session flow completed phone, OTP, and cloud
password authentication. TDLib reached ready state and `getMe` returned the
expected Telegram user id.

Log evidence included:

- `setTdlibParameters` accepted
- `authorizationStateWaitPhoneNumber`
- `auth.sendCode`
- `authorizationStateWaitCode`
- `authorizationStateWaitPassword`
- ready session after cloud password
- `getMe` user id `5009626431`

## Direct Upload Verification

Uploaded fixture:

- Device path: `/sdcard/Download/teledrive_tdlib_e2e_upload_2.png`
- Size: `387` bytes
- PNG validation: valid signature and chunk CRCs

Backend request evidence:

- `POST /api/client-uploads/prepare-target`
- `POST /api/client-uploads/init`
- `POST /api/client-uploads/27/file-started`
- `POST /api/client-uploads/27/file-complete`
- No `POST /api/files/upload` during the direct upload run

Database evidence:

- `files.id=62`
- `original_filename=teledrive_tdlib_e2e_upload_2.png`
- `storage_mode=client_managed`
- `upload_origin=client_tdlib`
- `upload_status=available`
- `verification_status=client_reported`
- `size_bytes=387`
- Exactly one original `file_media_objects` row
- `tdlib_chat_id=-1003989700583`
- `tdlib_message_id=11534336`
- `tdlib_file_id=1684`
- remote file id prefix: `BQACAgUAAyEGAATtzf_nAAML`

## Multi-File Direct Upload Verification

An 8-file direct upload regression was reproduced after the initial E2E pass:
the first two JPG files completed, while later files stayed in the client
`Preparing` state. Database evidence showed only the first two-file client batch
was created.

Root cause:

- Direct uploads were chunked by the client concurrency limit.
- Each chunk reused the same `upload_client_id`.
- The backend correctly treated the repeated id as an idempotency replay and
  returned the first two-file batch again.
- Later files therefore received no matching upload intent and stayed in
  `Preparing`.

Fixes applied:

- Direct upload chunks now use a stable chunk-specific backend
  `upload_client_id`, derived from the UI upload session and the local ids in
  that chunk.
- If the backend ever omits an upload slot or upload intent for a direct file,
  the item fails loudly instead of remaining in `Preparing`.
- The TDLib bridge now caches early `updateMessageSendSucceeded` and
  `updateMessageSendFailed` events so a fast final-message update cannot be
  lost before the final-message waiter is registered.
- The TDLib bridge now times out a missing final-message confirmation and frees
  the transfer instead of blocking the queue indefinitely.

Real-device rerun:

- Fixture set: `teledrive_batch_01.jpg` through `teledrive_batch_08.jpg`
- Device folder: `/sdcard/Download/teledrive_batch_e2e`
- Each file size: `535` bytes
- TDLib log evidence: eight `sendMessage` requests and eight
  `updateMessageSendSucceeded` updates.
- Client log evidence: all eight temporary picker files were deleted after
  successful upload.

Database evidence after the fixed rerun:

- Four client-direct backend batches were created: `34`, `35`, `36`, and `37`.
- Each batch completed `2/2` files and `1070/1070` bytes.
- Eight files were created: `71` through `78`.
- All eight files have:
  - `storage_mode=client_managed`
  - `upload_origin=client_tdlib`
  - `upload_status=available`
  - `verification_status=client_reported`
  - `size_bytes=535`
- All eight files have exactly one original `file_media_objects` row with
  available TDLib refs.
- The final original refs used `tdlib_chat_id=-1003989700583` and final
  positive TDLib message ids from `18874368` through `26214400`.

## Direct Download And Open Verification

Opening file `62` from Drive used the media-ref path:

- `GET /api/files/62/media-ref?variant=original` returned `200`
- No `GET /api/files/62/download` was observed

TDLib downloaded the original to local app storage:

`/data/data/com.example.flutter_m_fsdk/files/tdlib/351642e137af0790/2/5009626431/files/documents/teledrive_tdlib_e2e_upload_2.png`

The app opened the downloaded local file through its Android `FileProvider` as
`image/png`, and Android routed it to Google Photos.

## Legacy Fallback Verification

Direct upload/download flags were temporarily disabled in Flutter local config,
then the debug APK was rebuilt and installed.

Uploaded fixture:

- Device path: `/sdcard/Download/teledrive_legacy_fallback_upload.png`
- Size: `463` bytes
- PNG validation: valid signature and chunk CRCs

Backend evidence:

- `POST /api/files/upload` returned `202`
- Backend Telethon upload pipeline processed the file

Database evidence:

- `files.id=63`
- `original_filename=teledrive_legacy_fallback_upload.png`
- `storage_mode=legacy_server_managed`
- `upload_origin=backend_multipart`
- `upload_status=available`
- `verification_status=verified`

After this check, direct upload/download flags were restored.

## Public Share Verification

A public share was created for unverified client-managed file `62`.

- Share id: `4`
- Share token was generated locally and is intentionally not recorded here.
- Item public id: `c06qOemLnBNZvLvN`
- Manifest `availability=preparing`
- Manifest `canDownload=false`
- Manifest `downloadUrl=null`
- Manifest `publicProxyStatus=pending_verification`
- Manifest `storageMode=client_managed`
- Manifest unavailable reason: `Public download is preparing.`
- Direct public download returned HTTP `425`

This confirms the public page does not expose a working download URL for an
unverified client-managed file.

## Client-Side Thumbnail And Preview Implementation

Client-side derivative generation is now implemented behind
`CLIENT_DERIVATIVE_GENERATION_ENABLED`.

- Image uploads generate JPEG `thumbnail` and `preview` derivatives on-device.
- Video uploads generate JPEG poster thumbnails through the Android MediaStore
  bridge.
- Derivatives are uploaded through TDLib as separate media variants.
- `/client-uploads/{batch_id}/file-complete` now receives `thumbnail` and
  `preview` TDLib refs when generation succeeds.
- Pending commit recovery persists derivative refs together with the original
  ref, so a restart does not require regenerating or reuploading derivatives.
- Private app thumbnails for client-managed files now load through
  `/files/{file_id}/media-ref?variant=thumbnail` and TDLib local cache when no
  server URL is available.

Derivative failures are non-fatal: the original file still commits, and the
backend marks missing derivative variants unavailable instead of blocking the
upload.

## Gallery Backup Implementation

Gallery backup is now implemented behind `GALLERY_BACKUP_ENABLED` and remains
opt-in per device.

- Android MediaStore is scanned after the user enables Gallery Backup and grants
  media permission.
- Recent images/videos are queued in small batches for the existing direct TDLib
  upload pipeline.
- Gallery source files are marked as non-deletable, so successful uploads do not
  remove originals from the device gallery.
- Content-URI-only media is copied into app cache before TDLib upload and that
  cache copy is deleted after upload.
- Gallery uploads send `client_source=gallery_backup`, local modified time,
  relative path, and video duration when available.
- Wi-Fi-only backup follows the existing device upload network preference.

The implementation intentionally avoids a background OS scheduler for now; scans
run while the app is active and repeat periodically.

## Public Proxy Verification Implementation

Public proxy verification is now implemented for client-managed TDLib uploads.

- The backend derives a Telegram server message id only when the TDLib final
  message id cleanly maps to a server message id.
- The TDLib chat id must match the expected upload target channel.
- Telethon verifies the derived message exists before the backend marks the
  original object `verified`.
- Verified client-managed files receive server-side Telegram refs and can be
  served through public share proxy routes.
- Verified previews expose public preview URLs when a preview derivative exists
  and the configured public preview size limit allows it.
- Refs that cannot be verified remain `pending_verification`; public shares keep
  showing `preparing` with no working download URL.

Automated coverage added:

- `test_client_upload_complete_verifies_public_proxy_refs`
- Existing public share manifest tests for unverified, verified, and oversized
  client-managed files.

Post-implementation verification commands:

- `flutter analyze`
- `flutter build apk --debug`
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
- `python -m pytest backend/tests`
- Backend `8001` health check passed after restart with the new feature flags.

## Restart Recovery Verification

A default-off local test hook, `TDLIB_E2E_COMMIT_DELAY_SECONDS`, was used with
`45` seconds to create a deterministic gap after the durable pending commit was
saved and before `/client-uploads/{batch_id}/file-complete` was attempted.

Uploaded fixture:

- Device path: `/sdcard/Download/teledrive_restart_recovery.txt`
- Size: `133` bytes
- Plain text was used to remove any PNG fixture ambiguity from the recovery
  test.

Sequence verified:

1. Direct TDLib upload completed.
2. Flutter saved the pending commit locally before the backend commit attempt.
3. The backend listener on port `8001` was stopped during the test delay.
4. The app was force-stopped before `/file-complete` could succeed.
5. Before retry, the database showed:
   - `files.id=64`
   - `upload_status=client_uploading`
   - no `file_media_objects` rows for file `64`
   - `upload_batches.id=29`
   - `completed_files=0`
   - `completed_bytes=0`
6. The backend was restarted.
7. The app was relaunched.
8. Bootstrap retried the pending commit without reuploading to Telegram.

Client log evidence:

- `TDLIB_E2E_PENDING_COMMIT_SAVED id=29:64:9bf7fbb0-c5bc-4949-a6dc-8c8e161613cb delaySeconds=45`
- `TDLIB_E2E_PENDING_COMMIT_RETRY before=1`
- `TDLIB_E2E_PENDING_COMMIT_RETRY_RESULT attempted=1 committed=1 failed=0`

Backend evidence after restart:

- `POST /api/client-uploads/29/file-complete` returned `200`
- No replayed upload to Telegram was observed during retry
- No repeated `file-complete` was observed on a second app relaunch

Database evidence after retry:

- `files.id=64`
- `original_filename=teledrive_restart_recovery.txt`
- `storage_mode=client_managed`
- `upload_origin=client_tdlib`
- `upload_status=available`
- `verification_status=client_reported`
- `size_bytes=133`
- Exactly one original `file_media_objects` row
- `tdlib_chat_id=-1003989700583`
- `tdlib_message_id=13631488`
- `tdlib_file_id=1257`
- remote file id prefix: `BQACAgUAAyEGAATtzf_nAAMN`
- `upload_batches.id=29`
- `status=completed`
- `completed_files=1`
- `failed_files=0`
- `total_files=1`
- `completed_bytes=133`
- `total_bytes=133`
- `upload_jobs.id=64`
- `upload_mode=client_direct`
- `status=completed`
- `stage=available`
- `retry_count=0`

The pending record was removed after successful retry; a second relaunch did not
emit another retry or call `/file-complete` again.

The recovered file was visible in the Drive UI as
`teledrive_restart_recovery.txt` with size `133 B` and date `Today`.

After the restart-recovery test, `.env.local` was restored so
`TDLIB_E2E_COMMIT_DELAY_SECONDS` is not set for the final debug APK.

## Fixture Notes

The user suspected a corrupted PNG during verification. Local PNG chunk checks
showed:

- `teledrive_tdlib_e2e_upload_2.png`: valid
- `teledrive_legacy_fallback_upload.png`: valid
- `runtime-device-screen.png`: valid
- `runtime-viewer-screen.png`: valid
- `runtime-tdlib-e2e-upload.png`: corrupted `IDAT` CRC and truncated trailing
  chunk data

The corrupted `runtime-tdlib-e2e-upload.png` was not used as the final direct
upload proof. Restart recovery used a text fixture to avoid PNG-related
ambiguity.

## Known Limitations

- Gallery backup is Android-only in this build.
- Gallery backup scans while the app is active; there is no background OS
  scheduler yet.
- Public proxy verification is intentionally conservative. Client-managed refs
  that do not match the expected TDLib chat or final-message-id format remain
  unavailable for public sharing.
- Unverified client-managed public shares still intentionally show
  preparing/unavailable with no working download URL.
