# Study Planner Frontend

Flutter client for the Study Planner app. Android and Windows support offline storage with Drift/SQLite; the web build stores data in the browser. Signed-in users can sync with the Spring Boot API in `../backend`.

## Run

Install Flutter, then from this directory:

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api/v1

For Android Emulator, use `http://10.0.2.2:8080/api/v1`. For Flutter Web, run Chrome with `--web-port=5000` to match the backend's default CORS origin.

See the repository root README for backend setup, platform notes, and API details.
