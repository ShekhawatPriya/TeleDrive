# TeleDrive frontend — Codex guidance

## Working approach

- Inspect `git status --short` before editing; preserve unrelated edits, deletions, and untracked files. Keep changes scoped to the task, and separate UI redesign from incidental cleanup.
- Read the relevant implementation, tests, and docs before changing behavior. Resolve routine choices from those sources and complete implementation and verification without unnecessary confirmation.
- This is a Flutter Android/iOS client. The backend is a separate workspace; do not infer backend implementation from frontend docs or expand into backend/deployment changes unless the task requires them.
- For authorized backend/VPS work, use the backend repository's [operations handoff](https://github.com/ShekhawatPriya/TG-Cloud-Drive-BSDK/blob/main/docs/OPERATIONS-HANDOFF.md). The backend repository is canonical; do not hotfix `/opt/teledrive/app` and leave Git behind.
- Keep this file concise and durable. Link to detailed docs instead of copying histories, test counts, machine-specific paths, or full design specifications.

## Design references and precedence

For UI work, read the applicable documents before styling:

| Scope | Reference |
| --- | --- |
| General hierarchy, platform treatment, fixture review | [docs/design-workflow.md](docs/design-workflow.md) |
| Current iOS controls, account pages, browsing surfaces, sheets | [docs/ios-design.md](docs/ios-design.md) |
| Drive home ordering, geometry, search and keyboard behavior | [docs/drive-home-design.md](docs/drive-home-design.md) |
| Platform differences and hosted-backend compatibility | [docs/platform-design-and-vps.md](docs/platform-design-and-vps.md) |
| Cross-feature product contracts and modernization rationale | [docs/modernization.md](docs/modernization.md) |

These documents contain successive iterations and historical verification records. For overlapping UI guidance, use the current iOS and Drive-home refinements over the earlier generic frosted-dock/card descriptions, checking the implementation and tests. In particular, native UIKit navigation now exists, while custom iOS action sheets are opaque. Do not reintroduce an obsolete design because an older overview describes it. User-requested changes take precedence; update the relevant doc when intentionally changing the design contract. Do not rely on the removed `docs/m3/` tree or another machine's reference project.

### UI rules

- Preserve Android Material conventions and iOS Cupertino/native conventions with shared data and action contracts. Avoid duplicating business logic for platform-specific layouts.
- Reuse `lib/core/theme/app_theme.dart`, `ios_palette.dart`, and `tokens/` for colors, type, spacing, shape, motion, and state. Use semantic theme colors and system typography; follow the four-point spacing grid and documented screen-specific geometry. Avoid decorative gradients and a new competing palette.
- Reuse file/folder tiles, `AdaptiveSurface`, the `widgets/sheet/` components, and `IosPage`/`IosGroup`/`IosRow` in `lib/widgets/ios/ios_page.dart`. Inspect existing callers before introducing another shared abstraction.
- iOS `NativeTabBar` and `NativeGlassButton` bridge UIKit controls; native overflow menus need fresh state on every opening. Preserve Flutter fallbacks for missing bridges and widget tests. Custom Flutter blur is not native Liquid Glass.
- Keep glass on floating controls/navigation where already intended. Body content stays legible; iOS custom action sheets use opaque surfaces without a glass outline. Preserve continuous corners, safe-area/keyboard clearance, and avoid double clipping. Android surfaces remain opaque without backdrop-filter cost.
- Current iOS file thumbnails/captions sit directly on the page. Folder tiles are pale blue in light mode and black with a subtle outline in dark mode. Compact file rows use 40-point thumbnails, inset dividers, file metadata and thumbnail star status. Preserve selection, sharing, optimistic state, and item actions.
- Drive home order is search → spaces (Archive/Locked/Trash) → recents → folders → files, with the documented 20-point content inset. Keyboard Search dismisses the keyboard while preserving the query; Clear keeps editing active, and the separate X cancels the query and exits search. Floating upload controls hide while the keyboard occupies the shell.
- Keep 48 logical-pixel action targets by default; documented iOS controls must remain at least 44 points. Support 320-point widths, 200% text, light/dark themes, high contrast, reduced motion, semantic labels, keyboard focus, and reachable scrolling/actions. Do not clip text or shrink targets to make fixtures fit.
- Distinguish loading, empty, error/retry, and partial results. Use real model state; loaded counts are not whole-library totals. Do not invent activity, metrics, or security-audit results.

## Code map and conventions

- `lib/main.dart` loads local configuration and starts `ProviderScope`; `lib/app.dart` owns app composition. `lib/app_router.dart` owns GoRouter routes and persistent `StatefulShellRoute.indexedStack` tabs; `lib/main_shell.dart` coordinates navigation and upload controls. Preserve route paths, tab state, back behavior, and the iOS Account page stack and Android account-sheet navigation ordering.
- `lib/features/` contains screens, controllers, repositories, and feature components; `lib/models/` holds shared models. Follow the existing Riverpod providers and `ChangeNotifier` patterns rather than introducing a state-management migration.
- Larger controllers/repositories use Dart `part` files. Read the parent library and edit the appropriate part; do not import a part as a standalone library.
- `lib/core/network/` owns Dio and backend resolution; `core/storage/` owns preferences, secure storage, and caches; `core/media/` and `core/telegram/` own device media and transfers. Keep network/native operations out of presentation widgets.
- Native bridges live under `android/app/src/main/kotlin/` and `ios/Runner/`. Preserve channel contracts and both platforms when changing shared bridge behavior.
- Follow `analysis_options.yaml` and local Dart style. Format only changed Dart files; avoid broad formatting churn and unrelated dependency upgrades.

## Non-negotiable behavior contracts

- Read [docs/telegram-transfer-service.md](docs/telegram-transfer-service.md) for transfer changes. UI must use `lib/core/telegram`, never TDLib directly. Unsupported/unavailable direct transfers fail closed; do not send file bytes through a backend fallback.
- Direct uploads require matching active backend/Telegram identity and ready local authorization. Commit only final positive Telegram message IDs. Persist the scoped pending-commit record **before** the backend completion request; retry commits without reuploading. Pending commits block account switching/removal. Derivative failure must not discard a successful original upload.
- Preserve backend/user/Telegram scoping of sessions, encryption keys, pending commits, and caches. `AppConfig.storageNamespace` preserves identity across URL migration; do not replace it with the current network URL. Keep `BACKEND_PINNED` behavior: unreachable hosted service must not silently fall back elsewhere.
- Preserve account/generation checks across asynchronous reads and mutations, stale-search rejection, optimistic reconciliation, and revision-aware download caching. Candidate login must not overwrite active credentials before success.
- Keep API/auth service identity stable across resolver status notifications; `apiClientProvider` watches resolver notifier identity. Requests consult live connection state. Do not restore the lifecycle bug that recreated auth services while the router retained an older controller.
- Preserve lazy photo grids, pagination, bounded concurrency, subscription/timer cleanup, and local-cache-first video playback. Network retry must not blindly replay mutations.
- For native transfer changes, consult [docs/ios-build.md](docs/ios-build.md) and [docs/tdlib-real-device-verification.md](docs/tdlib-real-device-verification.md). Keep Android/iOS TDLib artifacts pinned to the same upstream commit.

## Setup and verification

For commit/push-only requests, treat the user's testing and validation as complete. Do not run tests, builds, linters, type checks, previews, or other validation commands. Read every changed file, account for removals and new files, and use Git status/history checks to stage, commit, and push the requested changes.

CI in `.github/workflows/verify.yml` pins Flutter **3.44.1**; `pubspec.yaml` requires Dart **^3.12.0**. Prefer the CI pin over the older README patch version. Android builds need JDK 17; iOS compilation needs macOS/Xcode.

Run commands from this directory. If `.env.local` is absent, copy `.env.example`; never overwrite existing local configuration. Run `flutter pub get` when dependencies are missing or changed, then:

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Use focused suites while iterating; add regression coverage for behavior changes and bugs. Run the full checks for code changes before delivery. For documentation-only edits, check links, paths, commands, and diff hygiene instead of rebuilding the app.

For visual changes, generate and **inspect** populated previews, not just passing assertions:

```sh
flutter test --no-pub test/modernization_ui_test.dart test/navigation_shell_test.dart --dart-define=WRITE_UI_PREVIEWS=true
dart run scripts/build_design_gallery.dart
```

Outputs are under `build/modernization/`, including `index.html`. Extend checks with the relevant suites:

- Drive/search/folders: `drive_search_dismissal_test.dart`, `platform_folder_ui_test.dart`.
- iOS controls/sheets: `ios_appearance_picker_test.dart`, `ios_action_contract_test.dart`, `native_menu_payload_test.dart`, `ios_glass_test.dart`.
- Auth/account/network: `auth_connection_lifetime_test.dart`, `drive_account_isolation_test.dart`, `async_boundaries_test.dart`, `switch_account_provider_test.dart`, `hosted_backend_config_test.dart`.
- Transfers/media/cache: `pending_telegram_commit_queue_test.dart`, `media_pipeline_regression_test.dart`, `download_cache_test.dart`, and affected backup tests.

All test names above are under `test/`. Cover both platforms/themes and constrained/accessibility layouts for affected UI. Fixtures belong in tests or `tools/ios_design_preview.dart`, never production providers. Use `-t lib/main.dart` for production/device runs; widget previews use portable fonts and cannot verify UIKit rendering.

Build Android integration changes with `flutter build apk --debug --no-pub`. Follow the iOS build guide for native iOS changes. Report separately what passed in unit/widget tests, rendered previews, native compilation, and actual device interaction; historical doc results are not current verification. State unavailable checks without claiming they passed.

## Configuration and delivery

- `.env.local` is bundled client configuration, not a secret vault. Do not print or commit local credentials, signing material, session data, or tokens. Public releases must have an empty `GITHUB_TOKEN`; preserve release-config checks and required release signing.
- Preserve installed application IDs, secure-storage identities, API paths, and user data unless a requested migration explicitly requires otherwise. Do not clear app data to make verification pass.
- Do not run release/secret/deployment scripts or live destructive account/file operations as routine validation. Use fixtures for automated checks.
- Before finishing, review the diff and report what changed, checks actually run, and material limitations. Update the relevant design/contract doc when behavior changes; avoid copying transient verification counts into this file.
