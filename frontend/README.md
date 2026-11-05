# Study Planner Frontend

Flutter client for the Study Planner app. Android and Windows support offline storage with Drift/SQLite; the web build stores data in the browser. Signed-in users can sync with the Spring Boot API in `../backend`.

## Run

Install Flutter, then from this directory:

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api

For Android Emulator, use `http://10.0.2.2:8080/api`. For Flutter Web, run `flutter run -d edge` or `flutter run -d chrome` from this directory. The development server uses `http://localhost:8386` from `web_dev_config.yaml`, and the client defaults to `http://localhost:8080/api`.

### Android Emulator installation

If the APK builds but ADB reports `Failure calling service package: Broken pipe`, run `adb -s emulator-5554 shell pm path android`. If that also fails, cold boot the AVD from Device Manager and wait for Android to finish booting. Then run Flutter again. To retry installing the APK already built, run:

```powershell
adb -s emulator-5554 install -r --no-streaming build/app/outputs/flutter-apk/app-debug.apk
```

`-r` keeps the app's existing data. If running a debug build with the default API URL `http://localhost:8080/api`, run `adb -s emulator-5554 reverse tcp:8080 tcp:8080` to reach the backend on the host. For a fresh build, use the emulator API URL above with `--dart-define=API_BASE_URL=http://10.0.2.2:8080/api`.

See the repository root README for backend setup, platform notes, and API details.
