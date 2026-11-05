# Study Planner Frontend

Flutter client for the Study Planner app. Android and Windows support offline storage with Drift/SQLite; the web build stores data in the browser. Signed-in users can sync with the Spring Boot API in `../backend`.

## Run

Install Flutter, then from this directory:

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api

For Android development, forward the host's backend port so the app can use its default API URL, `http://localhost:8080/api`.

```powershell
adb devices
adb -s emulator-5554 reverse tcp:8080 tcp:8080
flutter run -d emulator-5554
```

Use the device ID from `adb devices` for a different emulator or an Android phone with USB debugging enabled. Run the reverse command again after rebooting or reconnecting the device.

For Flutter Web, run `flutter run -d edge` or `flutter run -d chrome` from this directory. The development server uses `http://localhost:8386` from `web_dev_config.yaml`.

### Android Emulator installation

If the APK builds but ADB reports `Failure calling service package: Broken pipe`, run `adb -s emulator-5554 shell pm path android`. If that also fails, cold boot the AVD from Device Manager and wait for Android to finish booting. Then run Flutter again. To retry installing the APK already built, run:

```powershell
adb -s emulator-5554 install -r --no-streaming build/app/outputs/flutter-apk/app-debug.apk
```

`-r` keeps the app's existing data. Set up port forwarding as shown above before syncing the installed debug APK.

See the repository root README for backend setup, platform notes, and API details.
