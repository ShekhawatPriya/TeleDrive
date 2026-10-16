# Upload Live Activity and Dynamic Island

TeleDrive shows upload and photo-backup progress as an iOS Live Activity: on
the Lock Screen, in StandBy, and in the Dynamic Island. This document is the
design and behavior contract. The sources are Apple's
[Live Activities HIG](https://developer.apple.com/design/human-interface-guidelines/live-activities)
(revised October 2026 for limited-width layouts) and
[Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).

## Why a system Live Activity and not an in-app island

Expo-style "dynamic island notifications", such as
`rit3zh/expo-dynamic-notifications`, draw a fake island inside the app: a Skia
metaball droplet falls out of the camera cutout and morphs into a card. The
HIG asks apps **not** to draw attention to the Dynamic Island from inside the
app, because other system activity can occupy it while the app is open. The
real island is also the only one that works while TeleDrive is in the
background, which is when upload progress matters.

TeleDrive therefore uses ActivityKit. The system owns these interactions:

- **Collapsed (compact):** the progress ring sits on the leading side of the
  TrueDepth camera and the percentage on the trailing side.
- **Touch and hold:** the island expands to TeleDrive's expanded layout.
  Alerts also expand it briefly.
- **Tap:** opens TeleDrive at the upload panel (`teledrive://transfers`).
- **Several apps running activities:** the island uses the minimal ring. On
  iPhone 18 Pro, in landscape, and on iPhone Duo it uses the 28 pt
  limited-width layout (iOS 27 `isDynamicIslandLimitedInWidth`).

## Scope

- **One activity per upload session**, whether it came from the picker or from
  photo backup. Per the HIG, one activity tracks many items instead of one per
  file.
- **Not covered:** opening or downloading a file (short and foreground only),
  deletes, and pending Telegram commits. These have no meaningful time in the
  background.
- **Data:** everything shown comes from real queue state for this session.
  Counts are session counts, never library totals. There is no estimated time
  remaining, because the progress model weights preparation and derivative
  stages and an ETA would be invented precision.

## Presentations

All presentations derive their text and colors from one
`TransferPresentation`, so they never disagree.

| Phase | Ring glyph and tint | Compact trailing | Title |
| --- | --- | --- | --- |
| preparing | `arrow.up`, blue (indigo for backup) | `0%` | Preparing Upload/Backup |
| uploading | `arrow.up`, blue (indigo for backup) | `42%` | Uploading / Backing Up Photos |
| waitingForWifi | `wifi`, gray | `Wi-Fi` | Waiting for Wi-Fi |
| paused | `pause.fill`, gray | `Paused` | Upload/Backup Paused |
| completed | `checkmark`, green | `Done` | Upload/Backup Complete |
| partial | `exclamationmark`, orange | `N failed` | Upload/Backup Finished |
| failed | `xmark`, red | `Failed` | Upload/Backup Failed |
| cancelled | `xmark`, gray | `Stopped` | Upload Cancelled |

- **Expanded, while running (also paused or waiting):** the leading region
  shows a 46 pt ring and the trailing region a 28 pt rounded percentage, both
  hugging the camera so they keep their compact placement. The center region
  shows the title and the session count. The bottom region shows a full-width
  bar, the file in flight, and bytes.
- **Expanded, once settled:** the same grid as the running layout, with
  each element showing its final value in the same place. The ring becomes a
  50 pt tinted outcome disc with a solid glyph. The center region shows the
  final count ("Upload Complete" with "5 of 5 files"). The running percentage
  becomes the outcome figure: total size saved ("1.5 MB") on success, or
  "N failed". The bar shows the share that made it, and the file row becomes
  the outcome ("All files saved to TeleDrive", or "1 file didn't upload" with
  **Review** where the bytes were). The uploading presentation itself is
  unchanged.
- **Lock Screen and StandBy:** a TeleDrive logo mark without a container, drawn
  from `assets/icon/launch_mark.svg`, then the same ring, title, and
  percentage, with the bar and file row below. Settled sessions use the same
  outcome disc, figure, bar, and outcome row as the expanded island. It uses the standard 14 pt
  margin and the system background so it suits any wallpaper. Tint is reduced
  when luminance is reduced (Always-On). The key line tint follows the phase.
- **Privacy:** file names use `.privacySensitive()` and are dropped once the
  session settles. The HIG warns that Live Activities are visible to people
  nearby.
- **Motion:** the only motion is the system-timed content transitions
  (numeric text, glyph swaps). The system drops these on Always-On displays.

## Lifecycle contract

Dart (`TransferLiveActivityService`, fed by `uploadActivitySnapshot`) decides
what the activity says. Swift (`TransferLiveActivityBridge` on
`teledrive/live-activity`) owns ActivityKit and applies operations strictly in
order.

1. **Start:** starts when the first confirmed item leaves `selected`. Picked
   files that are still waiting for the large-upload confirmation never
   appear. ActivityKit only starts activities in the foreground. If a start is
   refused (Settings off, background, or system limit), it is retried at most
   every 30 s, and uploads never wait on it.
2. **Update:** structural changes (phase, counts, current file) are sent
   immediately. Percentage-only movement is sent at most once a second, and
   only when the whole percentage changes. A 60 s heartbeat refreshes the
   native stale date (150 s) while TeleDrive is actually running.
3. **Background:** leaving the app mid-upload starts a background task, so
   transfers keep running for the usual grace period. When iOS reclaims that
   time, the activity switches to **Paused, "Open TeleDrive to continue"**
   instead of freezing at a percentage. A stale running activity, for example
   after the process is killed, renders the same way. Returning to the app
   restores the last real state.
4. **Finish:** when the session settles, the controller calls `finish`:
   - **In the foreground:** the activity ends immediately with no alert,
     because the upload panel already showed the outcome.
   - **In the background:** the outcome stays in the island for 4 s, then the
     activity ends. The Lock Screen summary stays proportional to the session:
     2 to 15 minutes for success, 30 minutes when something failed, and
     immediate removal for cancellations.
   - **Alerts:** only when the matching *Upload Completed/Failed* setting is
     on. The alert travels with the activity update, which expands the island,
     and the local notification is skipped. The HIG asks apps not to notify
     twice for the same update. If the activity cannot deliver the alert,
     TeleDrive falls back to the local notification.
5. **Person removes it** from the Lock Screen: no restart for that session.
6. **Relaunch:** leftover activities from a previous process end at launch,
   because upload sessions are not restored.
7. **Account switch, sign-out, or clearing the queue:** the activity ends
   immediately.

## In-app status capsule (iOS)

Inside the app, the same session is summarized by the floating capsule beside
**+**, documented in [ios-design.md](ios-design.md#upload-presentation). It
uses the same status colors and ring language as the Live Activity.

## Settings

The **Settings → Notifications → Live Activities → Upload Progress** toggle is
on by default and only appears where ActivityKit exists (iOS 16.2 or later).
Turning it off ends any running activity. The system-level switch in the
iPhone's Settings still applies.

## Native layout

- `ios/Shared/TransferActivityAttributes.swift` is compiled into both targets
  and holds the 4 KB-bounded content state.
- `ios/TeleDriveActivities/` is the WidgetKit extension
  (`com.sree.tgclouddrive.TeleDriveActivities`, iOS 16.2+). Its version comes
  from `Flutter/Generated.xcconfig` so it always matches Runner.
- `ios/Runner/LiveActivity/TransferLiveActivityBridge.swift` is the channel,
  ordering, and suspension handling. `SceneDelegate` routes
  `teledrive://transfers`.
- The **Embed Foundation Extensions** phase must stay before Flutter's
  **Thin Binary** script. Moving it after that script creates an Xcode build
  cycle.
- The extension needs no App Group or other entitlement, and builds with Free
  Personal Teams.

## Verification

- `test/transfer_live_activity_test.dart` covers the mapper, throttling,
  heartbeat, start retry, removal, dismissal timing, alerts, and tap routing.
- `test/upload_cancellation_test.dart` (the Live Activity group) covers the
  controller wiring and alert de-duplication.
- `test/modernization_ui_test.dart` previews the settings group.

Widget tests cannot render ActivityKit. Check the presentations on a device
with a Dynamic Island: compact, expanded (touch and hold), minimal (with a
second app's activity), the Lock Screen in light and dark, Always-On, StandBy,
and landscape limited width. The Xcode canvas can preview the extension's
views.
