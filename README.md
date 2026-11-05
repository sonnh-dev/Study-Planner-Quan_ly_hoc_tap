# Study Planner

Ứng dụng quản lý việc học cho Android, Windows và Web. Flutter giữ phần giao diện, điều hướng Navigator và trạng thái cục bộ; REST API Spring Boot nằm riêng trong `backend/`.

## Kiến trúc

    frontend/  Flutter + Drift/SQLite + REST client + local notifications
    backend/   Spring Boot + Spring Security/JWT + Spring Data JPA + Flyway
    PostgreSQL Database đồng bộ giữa các thiết bị

| Thành phần | Địa chỉ khi chạy local | Cấu hình |
| --- | --- | --- |
| Frontend Web | `http://localhost:8386` | Dev server Flutter trong `frontend/web_dev_config.yaml` |
| Backend REST API | `http://localhost:8080/api` | Cổng Spring Boot qua `SERVER_PORT`, URL mà Flutter gọi qua `API_BASE_URL` |
| PostgreSQL | `localhost:5433` từ Windows, `postgres:5432` từ backend trong Docker | Kết nối JDBC của backend qua `DB_URL` |

Chạy Flutter và Spring Boot bằng hai tiến trình riêng. Trình duyệt tải giao diện từ cổng `8386` rồi gọi REST API ở cổng `8080` qua HTTP. Spring Boot cho phép origin Web qua `APP_CORS_ORIGINS` và là thành phần kết nối PostgreSQL.

- Android và Windows lưu lịch, roadmap, mindmap trong SQLite để dùng offline.
- Khi đăng nhập và có mạng, nút đồng bộ đẩy dữ liệu cục bộ lên PostgreSQL và tải dữ liệu của tài khoản về.
- Web dùng cùng frontend Flutter và lưu dữ liệu cục bộ trong trình duyệt; cần mạng để đăng nhập và đồng bộ qua Spring API. Mindmap editor chỉ mở trên màn hình PC.
- Chuông báo được đặt cục bộ trên Android và Windows. Web dùng dữ liệu cục bộ trong trình duyệt nhưng không gửi thông báo khi tab đã đóng.

## Chạy backend

Từ thư mục gốc, tạo `.env` nếu chưa có. Nếu máy đã có `backend/.env` cho dự án này, có thể dùng file đó bằng cách thay `.env` bằng `backend/.env` trong lệnh Docker Compose.

```powershell
if (-not (Test-Path .env)) {
    @(
        'DB_URL=jdbc:postgresql://localhost:5433/study_planner'
        'DB_USERNAME=study_planner'
        'DB_PASSWORD=study_planner'
        "JWT_SECRET=$([guid]::NewGuid().ToString('N'))"
        'APP_CORS_ORIGINS=http://localhost:8386,http://127.0.0.1:8386'
    ) | Set-Content -Encoding ascii .env
}
```

### Chạy bằng Docker Compose

Mở Docker Desktop, rồi chạy trong thư mục gốc của dự án:

```powershell
docker compose --env-file .env up -d --build backend
```

Compose khởi động PostgreSQL và Spring Boot. Kiểm tra API tại [trang health](http://localhost:8080/actuator/health). Chạy Flutter riêng theo phần bên dưới.

### Chạy Spring Boot trực tiếp

1. Cài JDK 21 và khởi động Docker Desktop. Project có Maven Wrapper, không cần cài Maven hoặc thêm `mvn` vào PATH. Lần đầu dùng wrapper cần mạng để tải Maven và dependencies.
2. Từ thư mục gốc, khởi động PostgreSQL:

    ```powershell
    docker compose --env-file .env up -d postgres
    ```

    PostgreSQL trong Docker dùng cổng host `5433`, tránh xung đột với PostgreSQL cài trực tiếp trên Windows thường dùng `5432`. Cấu hình trên dùng `jdbc:postgresql://localhost:5433/study_planner`, database/user/password local là `study_planner`. Nếu dùng PostgreSQL đã cài sẵn, tạo database/user tương ứng và sửa `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` trong `.env` theo server đó.
3. Trong `backend/`, chạy:

    ```powershell
    $env:SPRING_CONFIG_IMPORT = 'file:../.env[.properties]'
    .\mvnw.cmd spring-boot:run
    ```

    Trên Linux/macOS dùng `SPRING_CONFIG_IMPORT='file:../.env[.properties]' ./mvnw spring-boot:run`.
4. Kiểm tra API health: http://localhost:8080/actuator/health.

Spring Boot đọc `.env` qua `SPRING_CONFIG_IMPORT`. Bạn cũng có thể cung cấp cấu hình qua biến môi trường của tiến trình, vốn được ưu tiên hơn file. Khi triển khai, đặt secret riêng dài ít nhất 32 byte UTF-8. Flyway tự tạo schema khi backend khởi động.

Lưu ý: đổi `DB_PASSWORD` trong `.env` không đổi mật khẩu PostgreSQL của volume Docker đã có. Khi dùng lại volume cũ, dùng mật khẩu hiện tại hoặc đổi mật khẩu role trong database rồi cập nhật `.env`.

## Chạy Flutter

Chọn Flutter SDK đi kèm Dart 3.13.4 trở lên (nhánh Dart 3.x) theo `frontend/pubspec.yaml`.
Trên Windows, nếu `flutter pub get` báo lỗi quyền tạo symlink cho plugin, bật Developer Mode rồi chạy lại.

Trong frontend/:

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api

Android Emulator và điện thoại kết nối qua ADB dùng `http://localhost:8080/api`. Khi backend đang chạy trên máy tính, mở máy ảo hoặc kết nối điện thoại có bật USB debugging rồi chạy:

    adb devices
    adb -s emulator-5554 reverse tcp:8080 tcp:8080
    flutter run -d emulator-5554

Thay `emulator-5554` bằng ID trong `adb devices` khi chạy trên thiết bị khác. Chạy lại `adb reverse` sau khi khởi động lại máy ảo hoặc kết nối lại thiết bị. Kiểm tra bằng cách mở `http://localhost:8080/actuator/health` trên Android. Khi kết nối thành công, backend trả `{"status":"UP"}`.

Flutter Web trên máy Windows chạy backend:

    flutter run -d edge

Có thể dùng `-d chrome` nếu chạy bằng Chrome. File `frontend/web_dev_config.yaml` đặt Web tại `http://localhost:8386`. API mặc định là `http://localhost:8080/api`. Dừng lệnh `flutter run` cũ rồi chạy lại từ `frontend/` để áp dụng cấu hình. Trong DevTools, yêu cầu đăng ký có **Request URL** là `http://localhost:8080/api/auth/register`.

Khi chạy Web hoặc Android từ IntelliJ IDEA hay Android Studio, để trống `API_BASE_URL` trong **Additional run args** để dùng URL mặc định. Với Android, thiết lập `adb reverse` trước khi dùng chức năng đồng bộ.

Nếu backend đang dùng `APP_CORS_ORIGINS` từ cấu hình riêng, thêm `http://localhost:8386` vào danh sách origin rồi khởi động lại backend. Dữ liệu offline của Web được lưu theo địa chỉ và cổng. Nếu có dữ liệu cần chuyển từ cổng cũ, đồng bộ ở cổng cũ rồi đồng bộ lại ở cổng `8386`.

Drift cần sinh file app_database.g.dart bằng lệnh build_runner ở trên. Assets sqlite3.wasm và drift_worker.js cho Flutter Web được đặt sẵn trong frontend/web/.

## Tài khoản và dữ liệu

- Đăng ký bằng email và mật khẩu tối thiểu 8 ký tự.
- Backend chỉ trả dữ liệu thuộc tài khoản có JWT hợp lệ.
- JWT secret và thông tin PostgreSQL có thể đặt qua environment variables; không dùng secret mặc định khi chia sẻ môi trường.
- Khi đăng nhập và mở ứng dụng, lịch học tự đồng bộ mỗi phút. Nút **Đồng bộ dữ liệu** gửi và tải tất cả dữ liệu theo yêu cầu.

## Tài liệu

- [Đặc tả REST API](docs/api.md) gồm các endpoint `/api`, xác thực, dữ liệu gửi và mã lỗi.
- [Thiết kế cơ sở dữ liệu và mapping giao diện](docs/thiet-ke-du-lieu-va-api.md)
- [Môn học và Lộ trình](docs/mon-hoc-va-lo-trinh.md)
- [Hỏi đáp Flutter theo từng màn hình](docs/hoi-dap-flutter-theo-man-hinh.md)
