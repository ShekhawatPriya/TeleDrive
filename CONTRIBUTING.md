# Contributing

Thanks for helping improve TeleDrive.

## Development Setup

Follow the setup steps in [`README.md`](README.md), then run:

```sh
flutter analyze
flutter test
```

Run an Android build when changing platform integration:

```sh
flutter build apk --debug
```

## Pull Requests

- Keep UI changes separate from code cleanup. Existing screens should remain
  visually unchanged unless a pull request explicitly proposes a design change.
- Add focused tests for behavior changes and bug fixes.
- Do not commit `.env.local`, signing files, tokens, or backend credentials.
- Preserve the scoped TDLib storage and pending-commit recovery guarantees
  described in [`docs/telegram-transfer-service.md`](docs/telegram-transfer-service.md).
