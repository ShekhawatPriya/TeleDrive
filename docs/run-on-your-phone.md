# Run TeleDrive on your own phone

Use this after code changes to put the **real app** on your phone. All commands
run from the **Frontend** folder — the folder containing `pubspec.yaml`.
Always keep `-t lib/main.dart` in the command. The files under `tools/` are test
previews, not your normal app.

## Which mode should I use?

| What you want | Mode | What to expect |
| --- | --- | --- |
| See small UI/code edits quickly while working | **Debug** | Start once, then press `r` for hot reload. Keep the terminal and USB connection open. |
| Check scrolling, dragging and animation performance | **Profile** | Optimized performance with diagnostic tools. Every code change needs a new run. |
| Use the app normally, including unplugging your iPhone | **Release** | Optimized standalone app. Every code change needs a new run. No hot reload. |

**Fast updates = debug + hot reload. Smoothness testing = profile or release.**
Debug can stutter because of development overhead, so don't judge final animation
performance from it. [Flutter explains the modes here](https://docs.flutter.dev/testing/build-modes).

You do **not** need to run tests, make a separate APK, or run `flutter clean`
before every phone update. `flutter run` builds, installs and launches the app.
The first build or a native-code change takes longer; later builds reuse work.

## Mac → physical iPhone

### Everyday: install the latest app and use it normally

1. Plug in your iPhone, unlock it, and keep it unlocked during installation.
2. Open **Terminal** on the Mac.
3. For the current Mac and iPhone, copy these commands:

```sh
cd "/Users/sree/Code/Projects/Telegram/TeleDrive/Frontend"
flutter run --release -t lib/main.dart -d "00008150-001C6110148A401C"
```

That device ID is Sree's physical iPhone, verified when this guide was written.
If you change phones, run `flutter devices` and replace the ID with the one on
the **physical iPhone** row. Don't choose the iOS simulator row.

Wait for the build, installation and launch to finish. Once the app is open,
press **`d` in the running terminal** to detach and leave the app running. You can
then unplug the phone and open TeleDrive normally from its icon. This installs
locally; it does not publish anything to the App Store.

After more code changes, run the same command again to update the installed app.
Keep the existing bundle ID and signing team so it updates the same installation.

### Fast: see edits without rebuilding every time

```sh
cd "/Users/sree/Code/Projects/Telegram/TeleDrive/Frontend"
flutter run --debug -t lib/main.dart -d "00008150-001C6110148A401C"
```

Leave that terminal running. After I change the code, click that terminal and
press **`r`**. In this mode, a physical iPhone needs Flutter/Xcode to start its
debug engine; use the release command when you want reliable standalone use.

### Check how smooth a gesture really is

```sh
flutter run --profile -t lib/main.dart -d "00008150-001C6110148A401C"
```

Run this from Frontend. Profile has no hot reload. After code changes, press `q`
and run the command again. Release is also suitable for checking the everyday
feel of the app.

### First-time Mac/iPhone setup only

Skip this if the commands above already work.

1. Install Flutter (this repo's CI pins **3.44.1**), Xcode and CocoaPods. Run
   `flutter doctor -v` and resolve the iOS/Xcode setup items it reports.
2. Connect with a data-capable USB cable and accept **Trust This Computer**.
3. Enable **Settings → Privacy & Security → Developer Mode** on the iPhone;
   follow the restart/confirmation prompts. If the option is missing, open
   Xcode's **Window → Devices and Simulators** with the phone connected first.
4. From Frontend, prepare dependencies and open the Xcode workspace:

   ```sh
   flutter pub get
   open ios/Runner.xcworkspace
   ```

5. In Xcode, select **Runner → Signing & Capabilities**, enable automatic
   signing, and select your existing team. Keep the app ID
   `com.sree.tgclouddrive`. Do not create a different app ID to fix signing.
6. If the phone asks you to trust the developer app, use **Settings → General →
   VPN & Device Management** and trust your developer certificate.

Development signing can expire. Re-run the release command if a previously
working local install stops opening because of signing. See the detailed
[iOS build guide](ios-build.md) for provisioning and native dependencies, and
[Flutter's iOS setup](https://docs.flutter.dev/platform-integration/ios/setup).

## Windows → Android phone plugged in by USB

Use **PowerShell / Windows Terminal**. You do not need to install an emulator.

### First-time setup

1. Install Flutter **3.44.1** and Android Studio. Flutter's `bin` folder must be
   on PATH so `flutter` works in a new terminal. Install the Android SDK and
   Platform-Tools through Android Studio's SDK Manager.
2. Run `flutter doctor -v`. It tells you which Android SDK and Java installation
   Flutter uses. This project targets Java 17; follow the toolchain diagnostics
   rather than guessing from whether the separate `java` command works.
3. Run `flutter doctor --android-licenses`, read and accept the required licenses.
4. On the phone, enable Developer options (usually tap **Build number** seven
   times under About phone / Software information), then enable **USB debugging**.
5. Plug in a data-capable USB cable, unlock the phone, and accept **Allow USB
   debugging**. Try File transfer USB mode if Windows doesn't detect it. Some
   phones also need their manufacturer's Windows USB driver.

[Flutter's Android setup guide](https://docs.flutter.dev/platform-integration/android/setup)
has the full SDK and driver instructions.

### Open your project and choose the phone

In File Explorer, open your **Frontend** folder, right-click its empty space,
and choose **Open in Terminal**. Or use `cd` with your actual Windows path:

```powershell
cd "C:\replace-this-with-your-path\TeleDrive\Frontend"
flutter pub get
flutter devices
$teledrivePhone = Read-Host "Paste the Android device ID from the list"
```

Paste just the device ID from the Android phone row, then press Enter. Don't
choose Windows or Chrome. `$teledrivePhone` remembers your selection in this
terminal; repeat these steps when opening a new terminal.

**First time using this computer or switching signing identities:** check that
you can update the existing installation before using `flutter run`. Android
requires the same signing key for an in-place update. Different computers can
have different debug keys, and a release install can use another key. Flutter's
installer can retry an incompatible update by uninstalling, so do this safe check
first if you are unsure:

```powershell
flutter build apk --debug -t lib/main.dart
# Continue only if the build above succeeded.
$teledriveAdb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $teledriveAdb -s $teledrivePhone install -r ".\build\app\outputs\flutter-apk\app-debug.apk"
```

Use your SDK's actual path if Android Studio is installed elsewhere. `install -r`
requests an update preserving data and won't automatically uninstall on failure.
If it reports a signature mismatch / `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, stop
and ask to match the existing signing key. **Don't uninstall TeleDrive or clear
its data to fix that.** After a successful compatible update, use the commands below.

### Fast updates while working

```powershell
flutter run --debug -t lib/main.dart -d $teledrivePhone
```

Wait for TeleDrive to open. Leave the terminal running and press **`r`** after
Dart/UI edits. You don't need to stop, build an APK and reinstall each time.

For a normal Android test install, this same debug command is enough. Once it
has launched, press **`d`** to detach; the Android app remains installed and can
be opened from its icon. Re-run the command for further edits. Debug performance
still isn't representative of the optimized app.

### Check scrolling and drag performance

```powershell
flutter run --profile -t lib/main.dart -d $teledrivePhone
```

Keep the same compatible signing identity. There is no hot reload in profile;
press `q` and re-run after changes.

### Optimized standalone Android build

Use release only when this computer has the project's existing release-signing
setup and it matches the installation you want to update:

```powershell
flutter run --release -t lib/main.dart -d $teledrivePhone
```

This repository checks release signing and client configuration. If it reports
missing signing or a forbidden release-config value, resolve that setup rather
than disabling the checks. Never paste keys or tokens into a chat. Debug/profile
are the everyday development options; release is not required for hot reload.

## Mac fallback: build succeeds but Flutter says installation/launch failed

Keep the iPhone unlocked. Run the commands below **one at a time**, continuing
only when the previous command succeeds. They use Apple's device tool directly
and were used successfully for this phone. Replace the device ID for another phone.

```sh
flutter build ios --release -t lib/main.dart
xcrun devicectl device install app --device 00008150-001C6110148A401C build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device 00008150-001C6110148A401C com.sree.tgclouddrive
```

The last command should report that it launched the app. These commands update
the existing app; they do not require deleting its data. If Apple reports a
signing/trust error, follow the iPhone setup section above instead of uninstalling.

## What do I press after code changes?

Press these keys **inside the terminal currently running `flutter run`**, not in
a new terminal or on the phone. You usually don't need to press Enter.

| Key/action | What it does | When to use it |
| --- | --- | --- |
| `r` | Hot reload; usually keeps your current screen and in-memory state | Most Dart layout, color and widget edits in debug mode |
| `R` (Shift + r) | Hot restart; runs Dart startup again and resets in-memory UI state | Startup/state changes, or when `r` doesn't show the change |
| `q`, then re-run the command | Stops, rebuilds, reinstalls and starts the app | Swift/Kotlin/Java, native icons/bridges, plugins, platform configuration, or changed bundled configuration |
| `d` | Disconnects the tool while leaving the app running | Done testing; use release for standalone iPhone use |
| `h` | Shows the available terminal shortcuts | You forgot a key |

Hot restart doesn't mean deleting saved app data. It restarts the running Flutter
session. Hot reload doesn't rerun `main()` or `initState()`. Saving a file alone
in a plain terminal session isn't a request to reload; press `r`.
[Flutter's hot reload guide](https://docs.flutter.dev/tools/hot-reload) explains
which changes need a restart.

**Example:** if I change a photo layout in Dart, try `r`. If I change the native
iOS SF Symbol toolbar in Swift, press `q` and run your iPhone command again.
If you're already testing in release/profile, always stop and run again.

## Common problems

| Problem | What to do |
| --- | --- |
| `flutter` is not recognized | Add the Flutter SDK's `bin` directory to PATH and open a new terminal. |
| No `pubspec.yaml` found | You are in the wrong folder. Open **Frontend**. |
| Phone isn't listed | Unlock it, check USB Trust/debugging authorization and the data cable, then run `flutter devices` again. Android `unauthorized` means accept the phone's prompt. |
| iPhone installation waits or fails while locked | Unlock the phone and leave it unlocked during installation and launch. |
| iPhone debug app won't open from its icon | Start it with `flutter run --debug`, or install release for standalone use. |
| Change isn't visible | Save the source file, try `r`, then `R`; native/config changes require stopping and re-running. |
| Missing/changed dependencies | Run `flutter pub get`, then run again. |
| `Invalid SDK hash` after changing Flutter versions/computers | Ensure `flutter` and `dart` come from the same SDK (`which flutter dart` on Mac; `where.exe flutter` and `where.exe dart` on Windows). Then use `flutter clean`, `flutter pub get`, and re-run. This rebuilds generated files, not phone data. Don't clean on every edit. |
| Android signing mismatch | Stop; match the installed app's signing key. Don't delete the app to force installation. |
| Build works but files don't load | The phone still needs internet access to the hosted backend. A USB connection alone doesn't provide that. |

Keep your existing `.env.local`. On a fresh checkout only, if it is missing, copy
`.env.example` to `.env.local` and complete the local setup. Do not overwrite an
existing configuration or share its contents.

Normal hosted-backend testing does **not** need Docker, a local backend server,
`adb reverse`, or `scripts/connect-phone.ps1`. That older helper is for a separate
local-backend workflow and doesn't build your latest frontend changes. Keep the
hosted backend pin and storage identity unchanged.

Changes on the Mac don't automatically appear in your Windows checkout. Sync the
source changes before building on the other machine. Don't copy generated
`build/`, `.dart_tool/`, or `ios/Pods/` folders between computers. Run
`flutter pub get` in the destination checkout instead.
