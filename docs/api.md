# Study Planner REST API

## Địa chỉ và xác thực

Các endpoint nghiệp vụ dùng đường dẫn bắt đầu bằng `/api`. Bảng bên dưới ghi đầy đủ đường dẫn để dùng với địa chỉ backend.

| Môi trường | Backend | `API_BASE_URL` cho Flutter |
| --- | --- | --- |
| Windows và Flutter Web | `http://localhost:8080` | `http://localhost:8080/api` |
| Android Emulator | `http://10.0.2.2:8080` | `http://10.0.2.2:8080/api` |
| Điện thoại thật | `http://<IP-LAN-của-backend>:8080` | `http://<IP-LAN-của-backend>:8080/api` |

Flutter Web phục vụ giao diện ở `http://localhost:8386`. Backend mặc định cho phép CORS từ `http://localhost:8386` và `http://127.0.0.1:8386`. `APP_CORS_ORIGINS` cấu hình danh sách này. [Hướng dẫn chạy](../README.md) · [HTTP client](../frontend/lib/data/api_client.dart) · [Cấu hình Spring Boot](../backend/src/main/resources/application.yml)

- `POST /api/auth/register` và `POST /api/auth/login` là công khai. Cả hai trả JWT dùng ngay. JWT có thời hạn 7 ngày theo cấu hình hiện tại.
- Gửi `Authorization: Bearer <token>` cho API dữ liệu. Server lấy tài khoản từ token để kiểm tra quyền sở hữu.
- Gửi `Content-Type: application/json` cho `POST` và `PUT`. Có thể gửi `X-Request-Id` để nhận lại giá trị đó trong phản hồi do controller xử lý.
- `GET /actuator/health` là kiểm tra sức khỏe công khai, trả ví dụ `{"status":"UP"}`. Dùng URL này khi thử từ thanh địa chỉ trình duyệt. `GET /actuator/info` yêu cầu JWT. Các endpoint Actuator dùng định dạng riêng của Spring Boot.

[Cấu hình bảo mật](../backend/src/main/java/com/duy/studyplanner/api/config/SecurityConfig.java)

## Danh sách endpoint

| Phương thức và đường dẫn | JSON gửi lên | `result` khi thành công |
| --- | --- | --- |
| `POST /api/auth/register` | `AuthRequest` | `{ token, email }` |
| `POST /api/auth/login` | `AuthRequest` | `{ token, email }` |
| `GET /api/subjects` | — | Mảng `Subject`, sắp theo tên |
| `PUT /api/subjects/{id}` | `SubjectRequest` | `Subject` đã lưu |
| `GET /api/events` | — | Mảng `StudyEvent` chưa xóa, sắp theo giờ bắt đầu |
| `GET /api/events?includeDeleted=true` | — | Mảng `StudyEvent` gồm cả lịch đã xóa, dùng khi đồng bộ |
| `PUT /api/events/{id}` | `EventRequest` | `StudyEvent` đã lưu |
| `DELETE /api/events/{id}` | — | Phản hồi thành công với `result` được lược bỏ |
| `GET /api/subjects/{subjectId}/roadmap` | — | Mảng `RoadmapNode`, sắp theo `sortOrder` |
| `PUT /api/roadmap/{id}` | `RoadmapRequest` | `RoadmapNode` đã lưu |
| `GET /api/subjects/{subjectId}/mindmap` | — | Mảng `MindmapNode` của môn |
| `PUT /api/mindmap/{id}` | `MindmapRequest` | `MindmapNode` đã lưu |
| `DELETE /api/subjects/{subjectId}/mindmap/{id}` | — | Phản hồi thành công với `result` được lược bỏ |

`id` trên URL, `subjectId` và `parentId` là UUID. `PUT` tạo hoặc cập nhật theo ID. Gửi `parentId: null` hoặc bỏ trường để lưu node gốc. Nhánh cha phải cùng môn và cùng tài khoản. Mindmap kiểm tra vòng lặp, giữ thẻ trong môn ban đầu và đưa thẻ về gốc khi cha trực tiếp đã bị xóa.

Lệnh `DELETE /api/events/{id}` đánh dấu xóa mềm lịch của tài khoản hiện tại. Yêu cầu gửi lại, ID chưa tồn tại hoặc ID thuộc tài khoản khác đều trả HTTP `200` và `errorCode = "00000"`. Nếu gửi `PUT` cho lịch của mình đã xóa, server trả HTTP `410` với mã `01211`.

Lệnh `DELETE` của Mindmap đánh dấu xóa mềm, tách các thẻ con trực tiếp thành ý chính và có thể gửi lại. Danh sách Mindmap trả các thẻ còn hoạt động.

## Trường request và response

| Request | Bắt buộc | Tùy chọn và mặc định |
| --- | --- | --- |
| `AuthRequest` | `email` là địa chỉ email tối đa 254 ký tự. `password` là chuỗi 8–72 ký tự theo validation. | — |
| `SubjectRequest` | `name` là chuỗi tối đa 120 ký tự. `color` là chuỗi tối đa 20 ký tự. | — |
| `EventRequest` | `title` là chuỗi tối đa 160 ký tự. `startsAt` và `endsAt` là mốc ISO 8601. `endsAt` phải sau `startsAt`. | `details` tối đa 5.000 ký tự, mặc định chuỗi rỗng. `reminderAt` là mốc ISO 8601 hoặc `null`. |
| `RoadmapRequest` | `subjectId` và `title`. Tiêu đề tối đa 160 ký tự. | `parentId` có thể `null`. `note` tối đa 5.000 ký tự, mặc định chuỗi rỗng. `status` là `planned`, `in_progress` hoặc `done`, mặc định `planned`. `sortOrder` là số nguyên, mặc định `0`. `dueAt` là mốc ISO 8601 hoặc `null`. |
| `MindmapRequest` | `subjectId` và `title`. Tiêu đề tối đa 160 ký tự. | `parentId` có thể `null`. `content` tối đa 5.000 ký tự, mặc định chuỗi rỗng. `x` và `y` là số thực, mặc định `0` nếu bỏ qua. |

Server bỏ khoảng trắng đầu cuối và chuyển email thành chữ thường khi tra cứu hoặc lưu. Các trường tiêu đề và tên bắt buộc phải có nội dung. Thời gian trong JSON có thể gửi ở dạng UTC, ví dụ `2026-11-05T12:00:00Z`.

| Đối tượng trong `result` | Các trường |
| --- | --- |
| Phiên xác thực | `token`, `email` |
| `Subject` | `id`, `name`, `color`, `updatedAt` |
| `StudyEvent` | `id`, `title`, `details`, `startsAt`, `endsAt`, `reminderAt`, `deleted` (boolean) |
| `RoadmapNode` | `id`, `subjectId`, `parentId`, `title`, `note`, `status`, `sortOrder`, `dueAt` |
| `MindmapNode` | `id`, `subjectId`, `parentId`, `title`, `content`, `x`, `y` |

[Auth](../backend/src/main/java/com/duy/studyplanner/api/auth/AuthController.java) · [Môn học](../backend/src/main/java/com/duy/studyplanner/api/subject/SubjectController.java) · [Lịch học](../backend/src/main/java/com/duy/studyplanner/api/event/StudyEventController.java) · [Lộ trình](../backend/src/main/java/com/duy/studyplanner/api/roadmap/RoadmapController.java) · [Mindmap](../backend/src/main/java/com/duy/studyplanner/api/mindmap/MindmapController.java)

## Định dạng phản hồi và mã lỗi

Các endpoint nghiệp vụ trả HTTP `200` khi thành công, kể cả đăng ký, tạo bằng `PUT` và xóa lịch hoặc thẻ. Ví dụ danh sách môn rỗng khi đã gửi `X-Request-Id`.

```json
{
  "requestId": "subjects-001",
  "errorCode": "00000",
  "errorMessage": "Success",
  "result": []
}
```

JSON do controller trả có thể bỏ các trường `null`. Phản hồi lỗi dùng `errorCode` và `errorMessage`; lỗi CORS có thể do lớp bảo mật trả trực tiếp.

| HTTP | `errorCode` | Điều kiện |
| --- | --- | --- |
| `400` | `00101` | Dữ liệu vi phạm validation hoặc tham số URL sai kiểu, ví dụ `includeDeleted=abc` |
| `400` | `01102` | Giờ kết thúc lịch không sau giờ bắt đầu |
| `400` | `01103` | Trạng thái lộ trình sai |
| `400` | `01207` | Nhánh cha khác môn hoặc trùng nhánh đang lưu |
| `400` | `01209` | Liên kết Mindmap khác môn hoặc tạo vòng lặp |
| `401` | `00001` | Thiếu JWT hợp lệ trên endpoint yêu cầu đăng nhập |
| `401` | `01202` | Sai email hoặc mật khẩu |
| `401` | `01204` | Tài khoản trong token không còn tồn tại |
| `403` | `00002` | Spring Security từ chối quyền truy cập |
| `404` | `01203` | Không tìm thấy môn trong tài khoản |
| `404` | `01205` | Gửi cập nhật cho ID lịch thuộc tài khoản khác |
| `404` | `01206` | ID nhánh lộ trình thuộc tài khoản khác hoặc không tìm thấy nhánh cha |
| `404` | `01208` | ID thẻ không thuộc tài khoản hoặc môn yêu cầu, hoặc không tìm thấy thẻ cha |
| `409` | `01201` | Email đã đăng ký |
| `410` | `01210` | Gửi cập nhật cho thẻ Mindmap đã xóa |
| `410` | `01211` | Gửi cập nhật cho lịch học đã xóa |
| `500` | `00499` | Lỗi do bộ xử lý ngoại lệ chung tiếp nhận |

[Cấu trúc phản hồi](../backend/src/main/java/com/duy/studyplanner/api/common/ApiResponse.java) · [Xử lý lỗi](../backend/src/main/java/com/duy/studyplanner/api/common/GlobalExceptionHandler.java)

## Ví dụ đăng nhập, lưu và xóa lịch học

Thay email và mật khẩu mẫu bằng tài khoản đã đăng ký trên backend local.

```powershell
$api = 'http://localhost:8080/api'
$credentials = @{ email = 'demo@example.com'; password = 'your-password' } | ConvertTo-Json
$session = Invoke-RestMethod -Method Post -Uri "$api/auth/login" -ContentType 'application/json' -Body $credentials
$headers = @{ Authorization = "Bearer $($session.result.token)" }
$eventId = [guid]::NewGuid()
$event = @{
    title = 'Ôn cơ sở dữ liệu'
    details = 'Làm bài tập về khóa ngoại'
    startsAt = '2026-11-05T12:00:00Z'
    endsAt = '2026-11-05T13:00:00Z'
    reminderAt = '2026-11-05T11:50:00Z'
} | ConvertTo-Json
Invoke-RestMethod -Method Put -Uri "$api/events/$eventId" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body $event
Invoke-RestMethod -Method Get -Uri "$api/events" -Headers $headers
Invoke-RestMethod -Method Delete -Uri "$api/events/$eventId" -Headers $headers
Invoke-RestMethod -Method Get -Uri "$api/events?includeDeleted=true" -Headers $headers
```

Xem [thiết kế cơ sở dữ liệu và mapping giao diện](thiet-ke-du-lieu-va-api.md) để đối chiếu cột SQLite, cột PostgreSQL và dữ liệu hiển thị.
