# TDLib Android Artifacts

Direct Telegram transfers use the official TDLib JSON-for-Java artifact built
from the official `tdlib/td` repository. This app loads `libtdjsonjava.so` from
Android `jniLibs`; if the library is missing for the running ABI, direct media
transfer is disabled and the legacy backend fallback remains available.

Expected ABI layout:

- `arm64-v8a/libtdjsonjava.so`
- `x86_64/libtdjsonjava.so` for emulator testing
- `armeabi-v7a/libtdjsonjava.so` only if 32-bit Android support is required

Current vendored artifacts:

- Source: https://github.com/tdlib/td
- Commit: `e0943d068ce90b5010f1aea946e6901e25b43bf6`
- Build: official `example/android/Dockerfile`
- Interface: `JSONJava`
- `arm64-v8a/libtdjsonjava.so`: `6e26e09d99dd7165477724dcbec215043046dcb484f7f67ac188db8621c6f8dc`
- `x86_64/libtdjsonjava.so`: `3e5d56ced1dbecdc3c35ce1e5eebce4e775f53fc0fc01b9cf5fc89f93730ef29`
- `java/org/drinkless/tdlib/JsonClient.java`: `e92666f288e599d1c55bf5d24774f5e3e890b0999b0629931a7cf627a4323510`

Rebuild/update command:

```powershell
git clone --depth 1 https://github.com/tdlib/td.git $env:TEMP\tdlib-td
docker build --build-arg TDLIB_INTERFACE=JSONJava `
  --build-arg COMMIT_HASH=<commit> `
  --output $env:TEMP\tdlib-out `
  $env:TEMP\tdlib-td\example\android
```

Copy `tdlib/libs/<abi>/libtdjsonjava.so` into `jniLibs/<abi>/` and copy
`tdlib/java/org/drinkless/tdlib/JsonClient.java` into the matching Java source
package. Recompute SHA-256 checksums with `Get-FileHash -Algorithm SHA256`.

MethodChannel contract: `teledrive/tdlib`; EventChannel contract:
`teledrive/tdlib/events`.

The Kotlin bridge intentionally returns `tdlib_unavailable` when these artifacts
are absent, so uploads/downloads fail closed and can fall back to legacy paths.
