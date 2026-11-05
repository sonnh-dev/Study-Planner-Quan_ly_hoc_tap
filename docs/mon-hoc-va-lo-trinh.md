# Môn học và lộ trình học

Phạm vi của Hoàng Đức Thuận gồm đăng ký/đăng nhập, danh sách và chi tiết môn học, cây lộ trình, ghi chú, trạng thái học và đồng bộ dữ liệu của các màn hình này.

## Thiết kế dữ liệu

Môn học và lộ trình dùng hai bảng `subjects` và `roadmap_nodes`. Mỗi nhánh thuộc một môn qua `subject_id`. Nhánh con có `parent_id`, còn nhánh gốc dùng `NULL`. Giao diện tính tiến độ từ số nhánh có trạng thái `done`. Xem toàn bộ cột, khóa và giá trị mặc định trong [Database Design của Study Planner](thiet-ke-du-lieu-va-api.md).

## API của Môn học và Lộ trình

Đăng ký và đăng nhập dùng `POST /api/auth/register` và `POST /api/auth/login`. Đồng bộ môn dùng `GET /api/subjects` và `PUT /api/subjects/{id}`. Đồng bộ nhánh dùng `GET /api/subjects/{subjectId}/roadmap` và `PUT /api/roadmap/{id}`. Xem quy tắc xác thực, các trường và mã lỗi trong [đặc tả REST API](api.md).

Ví dụ JSON gửi cho `PUT /api/roadmap/{id}` khi lưu nhánh con.

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
| Đăng ký, đăng nhập | `email`, `password`, `result.token`, `result.email` | Gọi API Auth rồi mở màn hình chính khi nhận được token và email. Nếu bộ nhớ bảo mật báo lỗi khi lưu, app dùng phiên hiện tại trong bộ nhớ và yêu cầu đăng nhập lại khi mở lại. Nút tiếp tục offline mở ứng dụng từ dữ liệu cục bộ. |
| Danh sách môn | `subjects.id`, `name` | Đọc danh sách Drift. Thêm môn ghi bản ghi local mới với `is_synced = false`. Chạm tên môn mở chi tiết theo ID. |
| Chi tiết môn | `subject_id`, `parent_id`, `sort_order`, `title` | Lọc cây theo môn và nhóm nhánh theo ID cha. Tiến độ là số nhánh `done` trên tổng số nhánh của môn. |
| Thêm nhánh | `title`, `note`, `parentId` | Chọn chủ đề gốc hoặc nhánh cha trong cùng môn. Nhánh mới có trạng thái `planned`. |
| Chỉnh sửa nhánh | `note`, `status` | Mở nhánh để đọc và sửa ghi chú, chọn Chưa bắt đầu, Đang học hoặc Hoàn thành. Lưu vào Drift và đánh dấu chờ đồng bộ. |
| Đồng bộ dữ liệu | `is_synced`, UUID của môn và nhánh | Từ thanh công cụ, đẩy môn trước, đẩy nhánh cha trước nhánh con, rồi tải dữ liệu theo môn về Drift. |

Nút đồng bộ cần phiên đăng nhập và kết nối API. Nếu lưu nhánh trong lúc một bản cũ đang được gửi, bản local mới vẫn chờ đồng bộ. Lần tải về giữ bản local đang chờ gửi. Nếu hai thiết bị lần lượt gửi thay đổi trên cùng một nhánh, bản cập nhật sau cùng được ghi trên server. Giao diện không tự hợp nhất nội dung ghi chú giữa hai thiết bị.

## Kịch bản review

1. Chạy PostgreSQL, API và Flutter theo [README](../README.md). Đăng ký tài khoản demo mới hoặc đăng nhập bằng tài khoản đã có. Kiểm tra app mở màn hình chính và hiển thị email trong menu tài khoản.
2. Vào **Lộ trình**, tạo môn, mở chi tiết và thêm một nhánh gốc cùng một nhánh con. Kiểm tra hai môn hiển thị các cây riêng.
3. Mở nhánh con, sửa ghi chú và chọn **Hoàn thành**. Kiểm tra tiến độ và nút thu gọn/mở rộng.
4. Khi ứng dụng đã mở, ngắt kết nối đến API, mở lại chi tiết môn và sửa ghi chú. Kết nối lại, quay về màn hình chính rồi bấm **Đồng bộ dữ liệu**. Mở cùng tài khoản trong hồ sơ trình duyệt hoặc thiết bị riêng, đồng bộ và kiểm tra ghi chú, trạng thái.

Chạy `flutter test` từ thư mục `frontend`. Test giao diện kiểm tra chọn môn, đóng/mở nhánh, hủy và lưu chỉnh sửa. Test đồng bộ dùng SQLite trong bộ nhớ để kiểm tra thứ tự gửi cha–con, thử lại sau lỗi mạng và giữ bản chỉnh sửa mới trên thiết bị.
