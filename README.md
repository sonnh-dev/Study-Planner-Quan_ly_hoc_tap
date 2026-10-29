# Study Planner

Ứng dụng quản lý việc học cho Android, Windows và Web. Flutter giữ phần giao diện, điều hướng Navigator và trạng thái cục bộ; REST API Spring Boot nằm riêng trong `backend/`.

## Kiến trúc

    frontend/  Flutter + Drift/SQLite + REST client + local notifications
    backend/   Spring Boot + Spring Security/JWT + Spring Data JPA + Flyway
    PostgreSQL Database đồng bộ giữa các thiết bị

- Android và Windows lưu lịch, roadmap, mindmap trong SQLite để dùng offline.
- Khi đăng nhập và có mạng, nút đồng bộ đẩy dữ liệu cục bộ lên PostgreSQL và tải dữ liệu của tài khoản về.
- Web dùng cùng frontend Flutter và lưu dữ liệu cục bộ trong trình duyệt; cần mạng để đăng nhập và đồng bộ qua Spring API. Mindmap editor chỉ mở trên màn hình PC.
- Chuông báo được đặt cục bộ trên Android và Windows. Web dùng dữ liệu cục bộ trong trình duyệt nhưng không gửi thông báo khi tab đã đóng.

## Chạy backend

1. Cài JDK 21 và khởi động Docker Desktop. Project có Maven Wrapper, không cần cài Maven hoặc thêm `mvn` vào PATH. Lần đầu dùng wrapper cần mạng để tải Maven và dependencies.
2. Từ thư mục gốc, tạo cấu hình local nếu chưa có `.env`:

    ```powershell
    Copy-Item backend/.env.example backend/.env
    ```

    Trên Linux/macOS dùng `cp backend/.env.example backend/.env`. Giữ lại `.env` hiện có nếu đã cấu hình, và chỉnh thông tin kết nối khi cần.
3. Từ thư mục gốc, khởi động PostgreSQL:

    ```powershell
    docker compose --env-file backend/.env up -d postgres
    ```

    PostgreSQL trong Docker dùng cổng host `5433`, tránh xung đột với PostgreSQL cài trực tiếp trên Windows thường dùng `5432`. Cấu hình mẫu dùng `jdbc:postgresql://localhost:5433/study_planner`, database/user/password local là `study_planner`. Nếu dùng PostgreSQL đã cài sẵn, tạo database/user tương ứng và sửa `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` trong `backend/.env` theo server đó.
4. Trong `backend/`, chạy:

    ```powershell
    .\mvnw.cmd spring-boot:run
    ```

    Trên Linux/macOS dùng `./mvnw spring-boot:run`.
5. Kiểm tra API health: http://localhost:8080/actuator/health.

Backend tự đọc `backend/.env` khi thư mục chạy là gốc project hoặc `backend/`; biến môi trường của tiến trình được ưu tiên hơn file `.env`. `JWT_SECRET` trong file mẫu chỉ dành cho phát triển; khi triển khai, đặt secret riêng dài ít nhất 32 byte UTF-8. Flyway tự tạo schema khi backend khởi động.

Lưu ý: đổi `DB_PASSWORD` trong `.env` không đổi mật khẩu PostgreSQL của volume Docker đã có. Khi dùng lại volume cũ, dùng mật khẩu hiện tại hoặc đổi mật khẩu role trong database rồi cập nhật `.env`.

## Chạy Flutter

Trong frontend/:

    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080/api/v1

Android Emulator:

    flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

Điện thoại thật cần dùng địa chỉ IP LAN của máy chạy backend. Web có thể chạy trên Chrome với API URL http://localhost:8080/api/v1. Dùng flutter run -d chrome --web-port=5000 để khớp cấu hình CORS mặc định.

Drift cần sinh file app_database.g.dart bằng lệnh build_runner ở trên. Assets sqlite3.wasm và drift_worker.js cho Flutter Web được đặt sẵn trong frontend/web/.

## Tài khoản và dữ liệu

- Đăng ký bằng email và mật khẩu tối thiểu 8 ký tự.
- Backend chỉ trả dữ liệu thuộc tài khoản có JWT hợp lệ.
- JWT secret và thông tin PostgreSQL có thể đặt qua environment variables; không dùng secret mặc định khi chia sẻ môi trường.
- Offline mode không có đồng bộ; đăng nhập rồi bấm nút đồng bộ để chia sẻ dữ liệu giữa thiết bị.

## API chính

- POST /api/v1/auth/register, POST /api/v1/auth/login
- GET /api/v1/subjects, PUT /api/v1/subjects/{id}
- GET /api/v1/events, PUT /api/v1/events/{id}
- GET /api/v1/subjects/{subjectId}/roadmap, PUT /api/v1/roadmap/{id}
- GET /api/v1/subjects/{subjectId}/mindmap, PUT /api/v1/mindmap/{id}
