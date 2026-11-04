# Môn học và lộ trình học

Phạm vi của Hoàng Đức Thuận gồm đăng ký/đăng nhập, danh sách và chi tiết môn học, cây lộ trình, ghi chú, trạng thái học và đồng bộ dữ liệu của các màn hình này.

## Thiết kế dữ liệu

Flutter dùng Drift schema v1 với SQLite trên Android và Windows. Trên web, Drift dùng SQLite WASM và lưu qua trình duyệt. Màn hình đọc Drift nên dữ liệu đã lưu vẫn xem và chỉnh sửa được khi mất mạng. PostgreSQL giữ dữ liệu đồng bộ của từng tài khoản.

| Bảng Drift | Cột và kiểu | Vai trò |
| --- | --- | --- |
| `subjects` | `id TEXT PK`, `name TEXT`, `color TEXT`, `is_synced BOOL` | ID là UUID dạng chuỗi do Flutter tạo. Tên dài 1–120 ký tự. Màu mặc định là `#5685F7`. |
| `roadmap_nodes` | `id TEXT PK`, `subject_id TEXT`, `parent_id TEXT NULL`, `title TEXT`, `note TEXT`, `status TEXT`, `sort_order INTEGER`, `due_at INTEGER NULL`, `is_synced BOOL` | `subject_id` chọn môn. `parent_id` chỉ nhánh cha, để trống ở nhánh gốc. Hạn học nếu có được lưu bằng epoch milliseconds. |

`subject_id` và `parent_id` biểu diễn liên kết logic ở Drift. PostgreSQL áp dụng khóa ngoại cho hai liên kết này. Bảng server `app_users` có UUID, email duy nhất, mật khẩu băm BCrypt và thời điểm tạo. `subjects.user_id` và `roadmap_nodes.user_id` xác định chủ sở hữu. Token và email phiên nằm trong `SessionStore`, tách khỏi các bảng Drift. Cache Drift hiện dùng chung trong một bản cài hoặc hồ sơ trình duyệt, nên khi demo hai tài khoản, dùng hai hồ sơ trình duyệt hoặc hai thiết bị riêng.

Nguồn thiết kế gồm [schema Drift](../frontend/lib/data/app_database.dart) và [migration Flyway](../backend/src/main/resources/db/migration/V1__create_study_planner_tables.sql).

## Đặc tả API

Tiền tố `/api/v1`. Hai endpoint Auth nhận JSON công khai. Các endpoint còn lại yêu cầu header `Authorization: Bearer <token>`. Phản hồi thành công dùng `errorCode = "00000"` và dữ liệu nằm trong `result`. `X-Request-Id` có thể được gửi để đối chiếu request với response.

| Phương thức và đường dẫn | Dữ liệu gửi | `result` khi thành công |
| --- | --- | --- |
| `POST /auth/register` | `email`, `password` | `token`, `email` |
| `POST /auth/login` | `email`, `password` | `token`, `email` |
| `GET /subjects` | Không có body | Danh sách môn của tài khoản, sắp theo tên |
| `PUT /subjects/{id}` | `name`, `color` | Môn gồm `id`, `name`, `color`, `updatedAt` |
| `GET /subjects/{subjectId}/roadmap` | Không có body | Danh sách nhánh của môn, sắp theo `sortOrder` |
| `PUT /roadmap/{id}` | `subjectId`, `parentId`, `title`, `note`, `status`, `sortOrder`, `dueAt` | Nhánh gồm `id` và các trường tương ứng |

Hai lệnh `PUT` tạo hoặc cập nhật theo UUID trên URL. Email đăng ký tối đa 254 ký tự, mật khẩu từ 8 đến 72 ký tự theo validation. Email trùng trả `409`, thông tin đăng nhập sai hoặc thiếu JWT cho API riêng trả `401`. Dữ liệu không hợp lệ như trạng thái sai trả `400`. Môn hoặc nhánh cha không thuộc tài khoản trả `404`. Nhánh cha phải cùng môn và khác nhánh đang lưu.

Tên môn tối đa 120 ký tự, tên nhánh tối đa 160 ký tự, ghi chú tối đa 5.000 ký tự. `status` nhận `planned`, `in_progress` hoặc `done`. `parentId` và `dueAt` có thể rỗng, các trường rỗng có thể vắng mặt trong JSON phản hồi. Nếu có, `dueAt` là thời gian ISO 8601 UTC khi trao đổi qua API.

Ví dụ body cập nhật nhánh con

```json
{
  "subjectId": "22222222-2222-4222-8222-222222222222",
  "parentId": "33333333-3333-4333-8333-333333333333",
  "title": "Giới hạn",
  "note": "Làm lại bài 3.",
  "status": "done",
  "sortOrder": 1,
  "dueAt": null
}
```

## Mapping với giao diện và đồng bộ

| Giao diện hoặc thao tác | Trường liên quan | Hành vi |
| --- | --- | --- |
| Đăng ký, đăng nhập | `email`, `password`, `result.token`, `result.email` | Gọi API Auth rồi lưu phiên. Nút tiếp tục offline mở ứng dụng từ dữ liệu local. |
| Danh sách môn | `subjects.id`, `name` | Đọc danh sách Drift. Thêm môn ghi bản ghi local mới với `is_synced = false`. Chạm tên môn mở chi tiết theo ID. |
| Chi tiết môn | `subject_id`, `parent_id`, `sort_order`, `title` | Lọc cây theo môn và nhóm nhánh theo ID cha. Tiến độ là số nhánh `done` trên tổng số nhánh của môn. |
| Thêm nhánh | `title`, `note`, `parentId` | Chọn chủ đề gốc hoặc nhánh cha trong cùng môn. Nhánh mới có trạng thái `planned`. |
| Chỉnh sửa nhánh | `note`, `status` | Mở nhánh để đọc và sửa ghi chú, chọn Chưa bắt đầu, Đang học hoặc Hoàn thành. Lưu vào Drift và đánh dấu chờ đồng bộ. |
| Đồng bộ dữ liệu | `is_synced`, UUID của môn và nhánh | Từ thanh công cụ, đẩy môn trước, đẩy nhánh cha trước nhánh con, rồi tải dữ liệu theo môn về Drift. |

Nút đồng bộ cần phiên đăng nhập và kết nối API. Nếu lưu nhánh trong lúc một bản cũ đang được gửi, bản local mới vẫn chờ đồng bộ. Lần tải về giữ bản local đang chờ gửi. Nếu hai thiết bị lần lượt gửi thay đổi trên cùng một nhánh, bản cập nhật sau cùng được ghi trên server. Giao diện không tự hợp nhất nội dung ghi chú giữa hai thiết bị.

## Kịch bản review

1. Chạy PostgreSQL, API và Flutter theo [README](../README.md). Đăng ký rồi đăng nhập tài khoản demo.
2. Vào **Lộ trình**, tạo môn, mở chi tiết và thêm một nhánh gốc cùng một nhánh con. Kiểm tra hai môn hiển thị các cây riêng.
3. Mở nhánh con, sửa ghi chú và chọn **Hoàn thành**. Kiểm tra tiến độ và nút thu gọn/mở rộng.
4. Khi ứng dụng đã mở, ngắt kết nối đến API, mở lại chi tiết môn và sửa ghi chú. Kết nối lại, quay về màn hình chính rồi bấm **Đồng bộ dữ liệu**. Mở cùng tài khoản trong hồ sơ trình duyệt hoặc thiết bị riêng, đồng bộ và kiểm tra ghi chú, trạng thái.

Chạy `flutter test` từ thư mục `frontend`. Test giao diện kiểm tra chọn môn, đóng/mở nhánh, hủy và lưu chỉnh sửa. Test đồng bộ dùng SQLite trong bộ nhớ để kiểm tra thứ tự gửi cha–con, thử lại sau lỗi mạng và giữ bản chỉnh sửa mới trên thiết bị.
