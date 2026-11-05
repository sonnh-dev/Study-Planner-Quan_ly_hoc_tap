# Môn học và lộ trình học

Phạm vi của Hoàng Đức Thuận gồm đăng ký/đăng nhập, danh sách và chi tiết môn học, cây lộ trình, ghi chú, trạng thái học và đồng bộ dữ liệu của các màn hình này.

## Thiết kế dữ liệu

Môn học và lộ trình dùng hai bảng `subjects` và `roadmap_nodes`. Mỗi nhánh thuộc một môn qua `subject_id`. Nhánh con có `parent_id`, còn nhánh gốc dùng `NULL`. Giao diện tính tiến độ từ số nhánh có trạng thái `done`. Xem toàn bộ cột, khóa và giá trị mặc định trong [Database Design của Study Planner](thiet-ke-du-lieu-va-api.md).

## API của Môn học và Lộ trình

Đăng ký và đăng nhập dùng `POST /api/auth/register` và `POST /api/auth/login`. Môn học dùng `GET /api/subjects`, `PUT /api/subjects/{id}` và `DELETE /api/subjects/{id}`. Nhánh dùng `GET /api/subjects/{subjectId}/roadmap`, `PUT /api/roadmap/{id}` và `DELETE /api/subjects/{subjectId}/roadmap/{id}`. Đồng bộ dùng `includeDeleted=true` khi tải danh sách. Xem [đặc tả REST API](api.md).

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
| Danh sách môn | `subjects.id`, `name`, `color` | Tạo, mở, đổi tên hoặc xóa môn. Hộp thoại xác nhận nêu rõ xóa môn sẽ xóa lộ trình và Mindmap của môn trên thiết bị. |
| Chi tiết môn | `subject_id`, `parent_id`, `sort_order`, `title` | Gom nhánh theo cha, hỗ trợ thu gọn và chỉ dựng các hàng cần hiển thị. Thẻ tiến độ đếm số nhánh theo trạng thái. |
| Thêm hoặc sửa nhánh | `title`, `note`, `parentId`, `status`, `dueAt` | Chọn chủ đề gốc hoặc nhánh cha trong cùng môn. Bấm vào một dòng để sửa tên, ghi chú, trạng thái và hạn học. Menu của dòng có thao tác thêm nhánh con. |
| Xóa nhánh | `roadmap_deletions`, `parent_id` | Xóa nhánh đã chọn và đưa các nhánh con trực tiếp lên gốc. Yêu cầu xóa chờ gửi khi thiết bị offline. |
| Đồng bộ dữ liệu | `is_synced`, UUID của môn và nhánh | Từ thanh công cụ, đẩy môn trước, đẩy nhánh cha trước nhánh con, rồi tải dữ liệu theo môn về Drift. |

Nút đồng bộ cần phiên đăng nhập và kết nối API. Nếu lưu nhánh trong lúc một bản cũ đang được gửi, bản local mới vẫn chờ đồng bộ. Lần tải về giữ bản local đang chờ gửi. Nếu hai thiết bị lần lượt gửi thay đổi trên cùng một nhánh, bản cập nhật sau cùng được ghi trên server. Giao diện không tự hợp nhất nội dung ghi chú giữa hai thiết bị.

## Kịch bản review

1. Chạy PostgreSQL, API và Flutter theo [README](../README.md). Đăng ký tài khoản demo mới hoặc đăng nhập bằng tài khoản đã có. Kiểm tra app mở màn hình chính và hiển thị email trong menu tài khoản.
2. Vào **Lộ trình**, tạo môn, mở chi tiết và thêm một nhánh gốc cùng một nhánh con. Kiểm tra hai môn hiển thị các cây riêng.
3. Mở nhánh con, sửa tên và ghi chú, chọn **Hoàn thành** hoặc đặt hạn học. Kiểm tra tiến độ và nút thu gọn/mở rộng. Xóa nhánh cha và kiểm tra nhánh con xuất hiện ở cấp gốc.
4. Khi ứng dụng đã mở, ngắt kết nối đến API, mở lại chi tiết môn và sửa ghi chú. Kết nối lại, quay về màn hình chính rồi bấm **Đồng bộ dữ liệu**. Mở cùng tài khoản trong hồ sơ trình duyệt hoặc thiết bị riêng, đồng bộ và kiểm tra ghi chú, trạng thái.

Chạy `flutter test` từ thư mục `frontend`. Test giao diện kiểm tra chọn môn, đóng/mở nhánh, hủy và lưu chỉnh sửa. Test đồng bộ dùng SQLite trong bộ nhớ để kiểm tra thứ tự gửi cha–con, thử lại sau lỗi mạng và giữ bản chỉnh sửa mới trên thiết bị.
