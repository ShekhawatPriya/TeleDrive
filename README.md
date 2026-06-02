# TeleDrive

TeleDrive is an Android Flutter client for a Telegram-backed personal drive.
The app keeps file bytes on Telegram, uses the backend for metadata, and
performs supported uploads and downloads locally through TDLib.

## Architecture

- Flutter feature modules live under `lib/features`.
- Shared networking, storage, media, and TDLib integration live under
  `lib/core`.
- Android TDLib and MediaStore bridges live under
  `android/app/src/main/kotlin`.
- The backend is a separate service. This repository contains the mobile
  client.

Flutter UI code must not call TDLib directly. See
[`docs/telegram-transfer-service.md`](docs/telegram-transfer-service.md) for
the transfer contract and
[`docs/tdlib-real-device-verification.md`](docs/tdlib-real-device-verification.md)
for the real-device verification record.

## Requirements

- Flutter `3.44.0` stable
- Dart `3.12.0` (bundled with Flutter `3.44.0`)
- JDK `17`
- Android SDK
- A reachable TeleDrive backend
- Telegram API credentials from [my.telegram.org](https://my.telegram.org)

Release APKs target `arm64-v8a`. Debug builds also include `x86_64` for
emulator testing. TDLib artifact provenance and checksums are documented in
[`android/app/src/main/jniLibs/README.md`](android/app/src/main/jniLibs/README.md).

## Setup

```sh
cp .env.example .env.local
# Edit .env.local with your backend URL and Telegram API credentials.
flutter pub get
flutter run
```

`.env.local` is ignored by Git and bundled into local APKs at build time. Treat
its values as public client configuration: use a LAN-reachable or hosted
backend URL on a physical device and leave `GITHUB_TOKEN` empty for public
releases. `.env.example` is the tracked template only.

## Verification

```sh
flutter analyze
flutter test
```

Android builds additionally require JDK `17`:

```sh
flutter build apk --debug
```

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Security reports should follow
[`SECURITY.md`](SECURITY.md).

## License

A license has not been selected yet. Add a `LICENSE` file before distributing
this repository as open source.
