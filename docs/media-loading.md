# Visible-first media loading

`MediaThumb` is shared by Photos, Drive, folders, recents, and item sheets. Its
remote work is admitted by one `ThumbnailScheduler` per ProviderScope. Existing
local upload thumbnails retain Flutter's immediate image-cache path.

## Scheduling and recovery contract

- Measure each tile against its screen and ancestor scroll viewports after
  layout. Building a sliver cache child does not make it visible. Nested
  horizontal carousels also respect their viewport.
- Visible work precedes the 200-point nearby window. Admit at most four loads,
  at most one nearby prefetch, and at most one original-photo fallback.
  Originals are never prefetched. Decode remains bounded by the existing
  per-widget decode width (320/640/960 buckets for Photos tiles, chosen for
  their rendered size). The covered library suspends thumbnail work while its
  viewer is open, retaining its geometry and decoded images for the return.
- Promote queued work when it becomes visible. When new visible demand exceeds
  free capacity, cancel running nearby work. Release work when the final tile
  stops needing it, a route/tab becomes inactive, or the app leaves the
  foreground. App-pause cancellation does not depend on a future frame.
- Cover and grid requests for the same source share one operation. Releasing
  one consumer must not cancel a download needed by another.
- Check the account/revision disk cache before network admission. Revisiting a
  cached tile must not wait behind unrelated downloads. Cache keys include the
  stable backend namespace, backend and Telegram account IDs, file revision,
  derivative versions, and source identity. Rotating URL credentials are not
  content revisions. Retain at most 256 local path entries in memory; encoded
  thumbnails use the existing 3,000-object / 30-day thumbnail cache. Flutter
  continues to own decoded image caching.
- Reject corrupt or unsupported source bytes before storing a successful
  thumbnail. Advance through thumbnail/preview sources. Only after those fail
  may a visible image request its original, on the single original lane, and
  generate a portable 360-edge thumbnail using the existing media generator.
  This includes HEIC conversion on supported devices. Videos never download an
  original just to populate a tile.
- Errors are not cached. Visible failures retry twice, after 2 and 6 seconds,
  then stop automatic retrying. Re-entering the viewport retries; sufficiently
  large tiles also expose a labelled 44-point Retry preview control. Compact
  rows display a cloud-off status without shrinking an action target. Existing
  tile opening/selection gestures remain on the surrounding tile.
- Local Telegram setup is shared by concurrent requests and serialized across
  account changes. Check the account generation after every asynchronous stage,
  including A → B → A changes. A missing or mismatched `getMe` identity fails
  closed. No direct-transfer failure introduces a backend byte proxy.
- Cancellation reaches HTTP metadata/image reads and native downloads. The
  native transfer ID is registered before connection/message resolution; a
  cancelled lookup cannot later resurrect a download. Dart's native-call
  deadline includes lookup time, not only TDLib's download waiter. Thumbnail
  native calls have a 15-second deadline; original fallback uses 30 seconds.
  Viewer originals retain the viewer's longer timeout policy.

## Media cache tiers

Each tier has **one owner** and a time-aware LRU (TLRU) policy: entries idle
longer than a TTL expire, and a tier over its high watermark evicts
least-recently-used entries down to its low watermark. Recency is last
access, not download time: every hit touches the entry. Entries used within
the immunity window are never evicted, so on-screen or in-flight media stays.

| Tier | Owner | Budget |
| --- | --- | --- |
| Decoded images | Flutter `ImageCache`, plus `ThumbnailLoader`'s 256-path memory LRU | Flutter defaults; decode is bounded by tile size |
| Thumbnails | `TeleDriveThumbnailCacheManager` (`flutter_cache_manager`) | 3,000 objects, 30 days since last access |
| Previews (`teledrive_<hash>_<name>` in temp) | `MediaDiskCache` | 256 MiB → 192 MiB, 14-day TTL, 5-minute immunity |
| Originals (`teledrive-downloads/<revision>/`) | `DownloadCache` + `MediaDiskCache` trim | 1 GiB → 768 MiB, 7-day TTL; staging directories are immune |
| TDLib file store (application support) | native bridge | Not a cache tier: released once copied out |

Flow and invariants:

- **Cache-first.** `TelegramMediaAccessService.downloadForPrivateView` looks up
  the preview tier *before* account setup, media-ref requests, or TDLib. The key
  is scoped to the storage namespace, backend user, Telegram user, file id,
  variant, and file revision (modified time, size, derivative versions). It
  never depends on a backend-provided ref key, so lookup needs no network.
  `downloadToCache` checks the same file before invoking native code.
- **Atomic writes.** Native copies go to `<dest>.partial` and are renamed, so
  an interrupted copy is never a hit. Stale `.partial` files are swept.
- **No duplicates.** After copy-out the bridge sends TDLib `deleteFile`, but
  only for files inside TDLib's own files directory. A file uploaded from this
  device can point at a picker or staging path TDLib must not delete. The
  thumbnail loader deletes its transient `thumbnail`/`original` source once the
  thumbnail cache holds the bytes. The original loader *moves* its transient
  copy into the originals tier. Both delete or move only the bridge's own
  `teledrive_*` files, never a file the app does not own.
- **Maintenance.** Once per account generation, after TDLib is verified, the
  app runs TDLib `optimizeStorage` (64 MiB, 1-day TTL, 1-hour
  `immunity_delay`) to sweep legacy or interrupted files, and forces a
  `MediaDiskCache.trim()`. Further trims run after downloads, rate-limited to
  one per 30 seconds and single-flight. "Clear cache" also empties TDLib's
  store with `optimizeStorage(size: 0, ttl: 0, immunity_delay: 0)`.
- Everything here is re-fetchable from Telegram. Evicting a tier costs
  latency, never data. Upload staging and pending-commit records are not
  cache and are never trimmed by these rules.

References: Grab's [TLRU disk image cache](https://engineering.grab.com/reclaiming-tetabytes-optimizing-android-image-caching-with-tlru)
(size cap, last-access TTL, read refreshes recency) and TDLib
[`optimizeStorage`](https://core.telegram.org/tdlib/docs/classtd_1_1td__api_1_1optimize_storage.html)
(size/ttl/count limits by last access, `immunity_delay`), together with the
Glide and Fresco staged-cache references below. `test/media_disk_cache_test.dart`
covers eviction order, recency refresh, TTL, immunity, partial sweeps, and
staging protection. Budgets are starting points: tune them from real device
storage and hit-rate measurements, and keep this table current.

## Fresh TDLib database (re-login) contract

Every Telegram-backed image, video, preview, and original — grid tiles,
viewer, filmstrip, video playback, item sheets — goes through the native
`downloadToFile` bridge (`ios/Runner/Tdlib/TdlibBridge+Transfers.swift`,
`android/.../TdlibBridge.kt`). Fixing media loading belongs there, not in a
single screen.

**Failure this prevents.** After logging in again, TDLib starts with an empty
database: it knows no chats. Previously `getMessage(chat, message)` failed with
"Chat not found" for every stored media ref and the bridge fell back to:

- the stored remote file id, whose embedded file reference has usually expired.
  With no known source message TDLib cannot refresh it, so the download stopped
  silently and the tile spun until its timeout. Recently uploaded files still
  had fresh references, which is why only a few loaded;
- the stored `tdlibFileId`, a local id from the *previous* database that can
  name a different file in the new one.

**Required resolution order** (both platforms must match):

1. Wait for `connectionStateReady` **or** `connectionStateUpdating`; a fresh
   login can stay in "updating" for a long time while requests already work.
2. `getMessage`. On failure call `ensureChatKnown(chatId)`, then retry
   `getMessage` once. `ensureChatKnown` checks `getChat`, then pages
   `loadChats` through `chatListMain` and then `chatListArchive` (100 per page,
   at most 50 pages per list) until the chat appears or the list is exhausted.
   It is single-flight per chat, is not tied to one transfer's cancellation (a
   timed-out thumbnail's retry reuses the in-flight discovery), is forgotten on
   failure so the next request retries, and is cleared when the client is
   reconfigured. A downloaded message lets TDLib repair expired file references
   itself.
3. Only if the message cannot be used, the persistent remote file id.
4. A raw `tdlibFileId` only when the ref has neither message nor remote id.
5. When TDLib reports a file it was actively downloading as inactive and
   incomplete (`is_downloading_active` false), fail that waiter with
   `tdlib_download_stalled` immediately, so callers advance to the next source
   or show the retry/error state instead of spinning until the deadline.

`test/tdlib_download_resolution_contract_test.dart` pins these invariants in
both bridge sources. If you find a better approach (for example a backend-
provided chat title for `searchChatsOnServer`, or proactive chat warm-up after
login), change both bridges, update this section and that test together, and
keep the AGENTS.md pointer accurate.

These are admission limits, not promises of zero network latency. A missing
remote derivative, unavailable Telegram session, corrupt original, or offline
connection still needs recovery. Large originals may require opening the viewer
with its longer deadline. Actual cold-start and scrolling latency must be
measured on physical devices with representative libraries and connections.

## Published design references

- [Google Photos media access](https://developers.google.com/photos/library/guides/access-media-items)
  exposes stable media IDs and dimension-specific image delivery. Applied here
  as revision-scoped cache identity and small derivatives. This public API is
  not documentation of the private Google Photos app's scheduler.
- [Apple collection-view prefetching](https://developer.apple.com/documentation/uikit/prefetching-collection-view-data)
  describes asynchronous preparation of upcoming cells and cancelling obsolete
  fetches. Applied here to viewport admission and reference-counted cancellation.
- [Glide RecyclerView integration](https://bumptech.github.io/glide/int/recyclerview.html)
  recommends bounded preloading and matching preload/display dimensions so cache
  entries can be reused. TeleDrive retains lazy grids and a small nearby window.
- [Meta's Fresco image pipeline](https://engineering.fb.com/2015/03/26/android/introducing-fresco-a-new-image-library-for-android/)
  describes staged loading, caching, and releasing requests as views leave the
  screen. TeleDrive separates cached access, lightweight derivatives, expensive
  original recovery, and display decoding.

## Verification

Run the full analyzer and Flutter test suite. Focused coverage lives in:

- `test/thumbnail_scheduler_test.dart`: ordering, promotion, duplicate consumers,
  limits, in-flight prefetch preemption, cancellation, disposal, and retry.
- `test/thumbnail_visibility_test.dart`: clipped/nested viewports, scrolling,
  inactive tabs, and pause/resume.
- `test/media_thumb_loading_test.dart`: widget request admission, scrolling,
  hidden-tab cancellation, bounded retries, and retry controls.
- `test/thumbnail_loader_test.dart`: cold/warm/recreated cache access, account and
  revision separation, corrupt-source fallback, and late cancellation.
- `test/telegram_thumbnail_cancellation_test.dart`: native transfer cancellation,
  end-to-end timeout, and rejection of late results.
- `test/telegram_media_account_test.dart`: shared setup, account races, and
  fail-closed identity checks.

Render the populated Photos fixtures in `test/modernization_ui_test.dart` and
inspect both platforms and themes. Native changes additionally require Android
and iOS compilation. Fixture renders and mocked transfer tests are not evidence
of live Telegram performance.

### Verification on September 17, 2026

Flutter 3.44.1 / Dart 3.12.1 analysis passed. The full test run passed 254 tests;
three iOS login-layout tests failed identically on the untouched `ece9fa6`
baseline. No login implementation or baseline test was changed. All new media
loading regressions passed. Populated Photos light/dark previews for both
platforms and constrained retry-state previews were generated and inspected.
Android debug compilation used JDK 17; the iOS device debug build compiled
without signing. No physical Android/iOS device was connected, so live Telegram
latency, native cancellation under a real cellular connection, and on-device
frame timing remain unmeasured.
