# Hỏi đáp Flutter theo từng màn hình

Tài liệu đi theo 25 câu hỏi cho mỗi trang. **Lộ trình** được chia thành danh sách môn và chi tiết môn vì hai màn hình dùng route và stream khác nhau. Mindmap có cả trình chỉnh sửa và chế độ chỉ xem. Các mục live-code và “thử làm hỏng” mô tả bài tập và kết quả dự kiến.

1. [Đăng nhập và đăng ký](#1-đăng-nhập-và-đăng-ký)
2. [Tổng quan](#2-tổng-quan)
3. [Lịch học](#3-lịch-học)
4. [Lộ trình — Danh sách môn](#4-lộ-trình--danh-sách-môn)
5. [Lộ trình — Chi tiết môn](#5-lộ-trình--chi-tiết-môn)
6. [Mindmap](#6-mindmap)
7. [Tập trung](#7-tập-trung)
8. [Mẫu live-code và cách kiểm chứng](#mẫu-live-code-và-cách-kiểm-chứng)

### Các hành vi dùng chung

- **Điều hướng.** `StudyPlannerApp.build` chọn Login hoặc `AppShell` theo phiên. `AppShell._page` dùng `IndexedStack` và `_selected` để chuyển tab. Từ 820 px trở lên dùng `NavigationRail`, dưới ngưỡng dùng `NavigationBar`. Trang chi tiết môn là route được `push` riêng. [StudyPlannerApp](../frontend/lib/study_app.dart) · [AppShell](../frontend/lib/screens/app_shell.dart#L73)
- **Dữ liệu.** `main` tạo một `AppDatabase` và truyền qua cây widget. Các trang học tập đọc SQLite bằng stream Drift. `AppShell._sync` mới gọi `SyncService.sync()` và hiện SnackBar khi lỗi mạng hoặc API trả 500. Màn hình đăng nhập gọi API trực tiếp. [Khởi tạo](../frontend/lib/main.dart) · [Đồng bộ](../frontend/lib/screens/app_shell.dart#L49) · [SyncService](../frontend/lib/data/sync_service.dart)
- **Phiên.** `SessionStore` lưu JWT và email qua `FlutterSecureStorage`. `StudyPlannerApp` đưa JWT vào `ApiClient.token`, rồi `_request` gắn header Bearer. JWT hết hạn dẫn tới `ApiFailure(401)`; hiện tại đồng bộ báo lỗi và giữ màn hình đang mở. Đăng xuất do người dùng chọn. [SessionStore](../frontend/lib/data/session_store.dart) · [ApiClient](../frontend/lib/data/api_client.dart#L21)
- **Theme.** `MaterialApp` dùng Material 3, `ColorScheme.fromSeed`, màu nền và `CardThemeData`. App dùng font mặc định của Flutter/Material theo nền tảng. Đặt `ThemeData.fontFamily` và khai báo asset font trong `pubspec.yaml` nếu cần font toàn app. [Theme chung](../frontend/lib/study_app.dart#L107) · [pubspec](../frontend/pubspec.yaml)

## 1. Đăng nhập và đăng ký

[LoginScreen và `_submit`](../frontend/lib/screens/login_screen.dart#L20) · [Khôi phục và lưu phiên](../frontend/lib/study_app.dart#L42) · [API Auth](api.md)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | `Scaffold → SafeArea → SingleChildScrollView → Card`, chứa `_brandPanel` và `_form`. Đổi icon email ở `InputDecoration.prefixIcon` của ô email. Đổi màu khối thương hiệu tại `LinearGradient.colors` trong `_brandPanel`. |
| 02 | Tối ưu layout | Form có ít ô cố định nên dùng `Column` trong vùng cuộn. `ListView.builder` phù hợp nếu sau này có danh sách tài khoản dài. `itemBuilder(context, index)` tạo widget cho chỉ số được viewport yêu cầu, với giới hạn từ `itemCount`. |
| 03 | Overflow | Thông báo lỗi có thể xuống dòng trong `_form` và toàn form cuộn được. Hai cột ngang dùng `Expanded`. Panel thương hiệu cao cố định 520 px nên nội dung dài hoặc cỡ chữ lớn vẫn có thể tràn panel. |
| 04 | Responsive | `build` kiểm tra chiều rộng > 900 px để dùng hai cột, còn lại chỉ hiển thị form. Xoay ngang chỉ đổi bố cục nếu vượt ngưỡng. Sửa ngưỡng hoặc dùng `LayoutBuilder` khi muốn dựa trên chiều rộng vùng chứa. |
| 05 | Nguồn dữ liệu và lỗi | `_submit` gọi `ApiClient.post('/auth/login')` hoặc `post('/auth/register')`. `ApiFailure` và `ClientException` được chuyển thành `_error`, rồi `Text(_error!)` hiện dưới ô mật khẩu. HTTP 500 hiển thị thông báo server nếu có. |
| 06 | Lifecycle | `LoginScreen` khởi tạo hai controller trong State và dispose cả hai. `initState` khôi phục phiên nằm ở `StudyPlannerApp`. Quên dispose controller giữ listener và tài nguyên khi form bị gỡ. |
| 07 | UI tree | `build` dựng khung, `_brandPanel` dựng nhận diện và `_form` dựng form. Tách widget con giúp cô lập kiểm thử và đọc rõ trách nhiệm. Tách một hàm vẫn thuộc cùng phạm vi rebuild của State. |
| 08 | Tương tác | Nút chính có `FilledButton.onPressed` gọi `_submit`. Nút chuyển đăng ký đổi `_register`; nút offline gọi `widget.onContinueOffline`. Cả ba bị khóa khi `_busy`. |
| 09 | Theme | Form lấy kiểu chữ từ `Theme.of(context).textTheme`, màu lỗi từ `colorScheme.error`. Gradient và chữ trắng trong panel được đặt trong `_brandPanel`. |
| 10 | Data flow | Bấm Đăng ký → `_submit` bật `_busy` → POST JSON → lấy `result.token/email` → `_signedIn` lưu phiên và cập nhật `_token/_email` bằng `setState` → app dựng `AppShell`. |
| 11 | State | `setState` quản lý `_register/_busy/_error` cục bộ. Phiên đã nằm ở State gốc. Nếu nhiều trang cần quan sát phiên, có thể chuyển logic phiên vào `SessionController` được cấp trên `MaterialApp`. |
| 12 | Impact | Ví dụ thêm tên hiển thị lưu lâu dài. Cập nhật entity và schema tài khoản, DTO Auth, parse `result` trong Login, kiểu phiên/cách lưu trong `SessionStore`, rồi menu `AppShell`. Phân biệt trường mới lưu DB với nhãn suy ra từ email. |
| 13 | Rebuild | Đổi chế độ hoặc `_busy` dựng lại `LoginScreen`. Gõ làm `EditableText` cập nhật qua controller. Dùng DevTools Track Widget Builds để xem bấm đổi chế độ chỉ ảnh hưởng nhánh Login, còn đăng nhập thành công thay nhánh ở app gốc. |
| 14 | Null safety và JSON | `_submit` dùng map pattern, yêu cầu `token` là chuỗi không rỗng và `email` là chuỗi. Thiếu trường hoặc sai kiểu hiện lỗi phiên không hợp lệ. Luồng này parse trực tiếp thay vì gọi factory `fromJson` của Drift. |
| 15 | Navigation | Auth thành công làm `StudyPlannerApp.build` chọn `AppShell`. Không có route Login cũ được đẩy vào stack, vì vậy Back không quay lại form. Đăng xuất đổi lại nhánh gốc. |
| 16 | Data passing | Constructor `LoginScreen` nhận `api`, `onSignedIn` và `onContinueOffline`. Hàm callback trả `String token, String email` cho `StudyPlannerApp`. |
| 17 | Local storage | `_signedIn` gọi `session.save(token, email)`; `SessionStore` ghi email rồi JWT. `_restoreSession` đọc lúc khởi tạo app. Nếu ghi lỗi, phiên hiện tại nằm trong bộ nhớ. |
| 18 | Nợ kỹ thuật | Form đang vừa gửi HTTP, kiểm tra shape JSON, vừa ánh xạ lỗi UI. Khi Auth lớn hơn, tách `AuthRepository` với DTO kiểu rõ ràng, để form chỉ hiển thị trạng thái và lỗi. |
| 19 | Live-code xác nhận | Bọc `onPressed` của nút Đăng ký bằng `confirmAction(context)`. Sau khi trả `true` và `mounted`, gọi `_submit`. Giữ khóa `_busy`. |
| 20 | Async/await | Bỏ `await widget.onSignedIn(...)` làm `finally` có thể tắt `_busy` trước khi lưu phiên và lỗi async thoát khỏi `try/catch`. Sau `await`, `mounted` bảo đảm State còn tồn tại trước khi gọi `setState`. |
| 21 | Thử làm hỏng | Tạm bỏ `setState` cập nhật phiên trong `_signedIn`. Dự kiến API vẫn cấp JWT nhưng form có thể giữ nguyên vì app gốc chưa rebuild. Khôi phục `setState` và chạy test đăng ký. |
| 22 | Live-code debounce | Ô email hiện chỉ ghi vào controller. Nếu thêm kiểm tra email khi gõ, gắn `onChanged` với timer 500 ms và bỏ phản hồi cũ. Chỉ gửi email cho API kiểm tra được thiết kế riêng. |
| 23 | Auth/session | Server trả JWT ở `result.token`; app gốc giữ phiên và `ApiClient` gắn Bearer. HTTP 401 trên form hiện lỗi thông tin đăng nhập. Token hết hạn ở API riêng không tự chuyển trang. |
| 24 | Bộ nhớ | `dispose` gọi `_email.dispose()` và `_password.dispose()`. Các lời gọi HTTP là Future hữu hạn; kiểm tra `mounted` khi hoàn tất để tránh cập nhật widget đã gỡ. |
| 25 | Pagination | Endpoint Auth trả một phiên nên không phân trang. Nếu có màn chọn nhiều tài khoản, thêm API danh sách riêng và state `items/nextCursor/loadingMore`, rồi hiển thị bằng builder. |

## 2. Tổng quan

[OverviewScreen, thẻ số liệu và lịch](../frontend/lib/screens/overview_screen.dart) · [Hàm đổi tab](../frontend/lib/screens/app_shell.dart#L73)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | `StreamBuilder → ListView` chứa banner gradient, `Wrap` thẻ số liệu, hàng tiêu đề và `_EventTile` hoặc `_EmptyCard`. Đổi icon **Lịch sắp tới** tại tham số `icon` của `_StatCard`; đổi màu banner trong `LinearGradient.colors`. |
| 02 | Tối ưu layout | Code dùng `ListView(children: ...)` và chỉ dựng tối đa 4 lịch qua `events.take(4)`. `itemBuilder` chỉ cần khi chuyển sang danh sách dài. Tổng số lịch vẫn được tính từ tập dữ liệu đọc vào. |
| 03 | Overflow | Thẻ thống kê dùng `Expanded` cho cột chữ trong `Row`, `Wrap` cho nhiều thẻ, và `_EmptyCard` dùng `Expanded`. Tên lịch không đặt `maxLines`; nếu cần chiều cao ổn định, thêm giới hạn ở `_EventTile`. |
| 04 | Responsive | `Wrap` tự đưa thẻ sang hàng mới khi vùng chứa hẹp. Khi xoay ngang có thể xếp thêm thẻ trên một hàng; AppShell đổi thanh điều hướng theo 820 px. Sửa chiều rộng `_StatCard` hoặc dùng `LayoutBuilder` để chọn số cột rõ ràng. |
| 05 | Nguồn dữ liệu và lỗi | `watchEvents()` và `watchSubjects()` trong `AppDatabase`. Tổng quan đọc Drift, không gọi mạng khi build. Hai builder dùng giá trị rỗng khi chưa có snapshot; lỗi API lúc đồng bộ hiện qua SnackBar của `AppShell._sync`. |
| 06 | Lifecycle | Đây là `StatelessWidget`, nên không có `initState/dispose` của trang. `StreamBuilder` quản lý đăng ký stream; nếu tự thêm `.listen`, cần lưu subscription và hủy nó. |
| 07 | UI tree | `OverviewScreen` điều phối dữ liệu, `_StatCard`, `_EventTile`, `_EmptyCard` là các widget con. Có thể kiểm thử từng loại thẻ với dữ liệu khác nhau. |
| 08 | Tương tác | **Mở lịch** dùng `TextButton.icon(onPressed: onOpenSchedule)`. Tại `AppShell._page`, callback đặt `_selected = 1`. Các tile lịch hiện chỉ hiển thị. |
| 09 | Theme | Tiêu đề dùng `textTheme`. Màu gradient, màu từng thẻ và một số kiểu chữ nằm trong file Overview. Đổi màu icon của nhóm thống kê bằng tham số `color` của `_StatCard`. |
| 10 | Data flow | Mở lịch → callback ở Shell → `setState(_selected = 1)` → `IndexedStack` hiển thị tab Lịch. Khi lưu lịch ở tab Lịch, Drift phát danh sách mới và Tổng quan tính lại số lịch chưa kết thúc. |
| 11 | State | Snapshot của Drift là dữ liệu màn hình, còn chỉ số tab ở `AppShell`. Nếu số liệu dùng ở nhiều nơi, tách hàm tính hoặc stream tổng hợp ở lớp dữ liệu dùng chung. |
| 12 | Impact | Ví dụ hiện nhãn “Có nhắc”. `reminderAt` đã có từ model và sync, nên chỉ đổi `_EventTile`. Trường thực sự mới phải đi qua migration/DTO server, parse trong `SyncService`, schema Drift và widget. |
| 13 | Rebuild | Event stream có dữ liệu mới thì builder ngoài dựng lại cây Tổng quan. Stream môn nằm trong thẻ số môn; phát riêng sẽ cập nhật builder thẻ đó. Bật Track Widget Builds rồi lưu một môn và một lịch để so sánh. |
| 14 | Null safety và JSON | `_pullEvents` cast `title/startsAt/endsAt` và parse ngày. Thiếu trường bắt buộc làm đồng bộ lỗi. `details` thiếu thì dùng `''`, `reminderAt` thiếu thì `null`; Tổng quan nhận model Drift đã tạo. |
| 15 | Navigation | **Mở lịch** đổi chỉ số tab, nên không có route Tổng quan mới trong stack. Back không được ánh xạ về tab trước. |
| 16 | Data passing | `OverviewScreen({required database, required onOpenSchedule})` nhận dependency từ Shell. `_EventTile(event: event)` nhận một `StudyEvent` từ danh sách đã lọc. |
| 17 | Local storage | Tổng quan chỉ đọc. `ScheduleScreen._applyChange` ghi thay đổi lịch, `SyncService._pullEvents` áp dụng dữ liệu từ server và `watchEvents()` phát danh sách mới lên UI. |
| 18 | Nợ kỹ thuật | Mỗi lần builder chạy, `where` lọc toàn bộ lịch rồi mới lấy 4. Với dữ liệu lớn, dùng query Drift lọc theo `ends_at`, đếm riêng và giới hạn 4. |
| 19 | Live-code xác nhận | Trong `TextButton.icon` của **Mở lịch**, đợi `confirmAction(context)`. Nếu đồng ý và `context.mounted`, gọi `onOpenSchedule()`. |
| 20 | Async/await | Chỗ phù hợp để thử là callback xác nhận mới. Bỏ `await` làm kết quả vẫn là `Future<bool>`; cần đợi rồi kiểm tra `context.mounted` trước khi điều hướng. |
| 21 | Thử làm hỏng | Tạm bỏ bộ lọc `event.endsAt >= now.millisecondsSinceEpoch`. Dự kiến lịch đã qua xuất hiện trong số liệu và danh sách gần nhất. Khôi phục lọc hoặc chuyển điều kiện vào query Drift. |
| 22 | Live-code debounce | Trang hiện không có ô gõ. Nếu thêm lọc lịch, cập nhật query cục bộ sau 500 ms khi dữ liệu lớn, rồi dùng builder đọc kết quả. |
| 23 | Auth/session | Đọc Tổng quan vẫn dùng SQLite ở chế độ offline. Đồng bộ trên thanh trên dùng Bearer chung và hiện lỗi nếu 401; trang Tổng quan không điều hướng khi lỗi phiên. |
| 24 | Bộ nhớ | Hai `StreamBuilder` tự ngắt subscription khi bị gỡ. Stream được gọi trong `build`, nên có thể được tạo lại khi widget cha rebuild. Kiểm tra số subscription bằng log hoặc test, thay vì suy ra từ việc tách widget. |
| 25 | Pagination | Giữ danh sách gần nhất giới hạn 4 và lấy tổng số từ query riêng. Nếu thêm **Xem thêm**, chuyển sang Lịch học với state trang và cursor riêng. |

## 3. Lịch học

[ScheduleScreen](../frontend/lib/screens/schedule_screen.dart#L44) · [Bảng theo ngày](../frontend/lib/screens/schedule_screen.dart#L381) · [Hộp thoại thêm và sửa](../frontend/lib/screens/schedule_screen.dart#L579) · [Query Drift](../frontend/lib/data/app_database.dart#L169) · [Đồng bộ lịch](../frontend/lib/data/sync_service.dart)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | Trang có tiêu đề **Ngày của tôi**, dải 7 ngày, nút **Thêm lịch** và bảng **Khung giờ / Buổi học**. Đổi biểu tượng nhắc ở `_DayTable`. |
| 02 | Tối ưu layout | `ListView` dựng phần tiêu đề và các dòng của ngày đang chọn. Nếu cần hiển thị nhiều dòng trong một ngày, có thể đưa chúng vào `SliverList.builder`. |
| 03 | Overflow | Tiêu đề và nút thêm nằm trong `Wrap`. Ghi chú trong bảng hiện tối đa hai dòng. `AlertDialog(scrollable: true)` cho phép cuộn form. |
| 04 | Responsive | `LayoutBuilder` xét chiều rộng thực tế của trang. Dưới 560 px, khung giờ xuống hai dòng và thao tác sửa/xóa nằm trong menu. Từ 560 px, mỗi dòng có hai nút riêng. |
| 05 | Nguồn dữ liệu và lỗi | `watchEvents()` đọc `study_events` theo giờ bắt đầu. `StreamBuilder` hiển thị trạng thái tải và lỗi đọc. `AppShell._sync` báo lỗi đồng bộ. |
| 06 | Lifecycle | `ScheduleScreen` là `StatefulWidget`. Stream được giữ qua các lần rebuild và đổi khi nhận database mới. `_EventDialogState` dispose hai controller khi hộp thoại đóng. |
| 07 | UI tree | `StreamBuilder → LayoutBuilder → ListView → Center → ConstrainedBox → Column`. Cột chứa tiêu đề, điều hướng ngày, `_WeekStrip` và `_DayTable`. Bảng dùng `Card → Column`, mỗi lịch là một `InkWell → Row`. |
| 08 | Tương tác | **Thêm lịch** mở form theo ngày đang chọn. Bấm dòng hoặc nút **Sửa lịch** mở form có sẵn dữ liệu. **Xóa lịch** mở hộp thoại xác nhận. |
| 09 | Theme | Ngày đang chọn dùng `primaryContainer`. Tiêu đề, giờ và chuông dùng `primary`. Nút xóa trên màn hình rộng dùng `error`. |
| 10 | Data flow | **Lưu lịch** kiểm tra form rồi trả `StudyEvent` qua `Navigator.pop`. `_applyChange` gọi `saveEvent` khi thêm hoặc `updateEvent` khi sửa. Drift phát danh sách mới sau giao dịch. |
| 11 | State | Trang giữ `_day` và `_saving`. Hộp thoại giữ hai controller cùng `_starts`, `_ends`, `_reminder` và `_error`. Lịch đã lưu nằm trong Drift. |
| 12 | Thay đổi DB và API | Drift v3 thêm `study_event_deletions`. Flyway V3 thêm `study_events.is_deleted`. Sửa lịch dùng `PUT` với UUID cũ. Xóa dùng `DELETE /api/events/{id}`. Thiết bị khác đọc cờ xóa qua `GET /api/events?includeDeleted=true`. |
| 13 | Rebuild | Chọn ngày lọc lại snapshot hiện có. Sửa giờ trong form chỉ dựng lại hộp thoại. Khi lưu SQLite, các màn hình đang nghe lịch nhận danh sách mới. |
| 14 | Null safety và JSON | `startsAt` và `endsAt` dùng ISO 8601 và bắt buộc có khi tải lịch còn hoạt động. `reminderAt` có thể thiếu hoặc `null`. Bản ghi có `deleted: true` được xử lý trước khi đọc các mốc giờ. |
| 15 | Navigation | `showDialog<StudyEvent>` trả lịch khi bấm **Lưu lịch** và trả `null` khi hủy. Hộp thoại xác nhận xóa trả `true` khi người dùng xác nhận. |
| 16 | Data passing | Shell truyền `database` và `notifications`. `_DayTable` nhận ngày, danh sách buổi và callback. `_EventDialog` nhận ngày mặc định và bản ghi cũ nếu đang sửa. |
| 17 | Local storage | Xóa lịch và đưa UUID vào `study_event_deletions` trong một giao dịch SQLite. Hàng đợi giữ UUID đến khi server xác nhận. |
| 18 | Validation và mã lỗi | Form báo lỗi khi thiếu tên hoặc giờ kết thúc không sau giờ bắt đầu. API dùng `01102` với HTTP `400` nếu khoảng giờ sai, `01205` với HTTP `404` nếu cập nhật lịch thuộc tài khoản khác và `01211` với HTTP `410` nếu cập nhật lịch đã xóa. |
| 19 | Live-code xác nhận | Mở **Xóa lịch**, bấm **Hủy** rồi kiểm tra dòng vẫn còn. Mở lại và xác nhận để kiểm tra dòng biến mất, kể cả khi offline. |
| 20 | Async/await | `_applyChange` chờ ghi SQLite rồi cập nhật nhắc giờ. Các callback chọn ngày hoặc giờ kiểm tra `mounted` trước khi cập nhật widget. |
| 21 | Thử làm hỏng | Đặt giờ kết thúc bằng giờ bắt đầu rồi bấm **Lưu lịch**. Form phải báo lỗi và giữ nguyên dữ liệu đã lưu. |
| 22 | Live-code lọc theo ngày | Tạo một buổi qua nửa đêm và chuyển qua hai ngày liên tiếp. Ngày đầu hiển thị đến `24:00`, ngày sau hiển thị từ `00:00`. |
| 23 | Auth/session | Thêm, sửa và xóa đều chạy qua SQLite. Sau khi đăng nhập hoặc khôi phục phiên, Shell đồng bộ lịch mỗi phút khi app đang mở. Nút **Đồng bộ dữ liệu** chạy đồng bộ toàn bộ và báo lỗi khi thất bại. |
| 24 | Bộ nhớ | `StreamBuilder` quản lý subscription. Hai controller của form được dispose. Lịch nhắc do hệ điều hành quản lý và được cập nhật khi sửa hoặc xóa. |
| 25 | Phân trang | API lịch hiện trả danh sách của tài khoản. Flutter lấy các buổi giao với ngày đang chọn để dựng bảng. |

## 4. Lộ trình — Danh sách môn

[RoadmapScreen và `_editSubject`](../frontend/lib/screens/roadmap_screen.dart#L16) · [Query môn học](../frontend/lib/data/app_database.dart#L119) · [API môn học](api.md#danh-sách-endpoint)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | `StreamBuilder → _RoadmapList → ListView.builder`. Mỗi môn hiện tên, icon lấy màu môn và menu đổi tên hoặc xóa. |
| 02 | Tối ưu layout | `ListView.builder` dựng từng dòng khi cần hiển thị. `ValueKey(subject.id)` xác định dòng theo ID. |
| 03 | Overflow | Form thêm môn dùng `AlertDialog(scrollable: true)`. Tên môn trên tile là `Text(subject.name)`; chưa giới hạn dòng. Thêm `maxLines` và `TextOverflow.ellipsis` nếu muốn tile cố định. |
| 04 | Responsive | Danh sách giới hạn chiều rộng 920 px. Tiêu đề và nút thêm nằm trong `Wrap` để tự xuống dòng trên màn hình hẹp. |
| 05 | Nguồn dữ liệu và lỗi | `watchSubjects()` đọc Drift theo tên. Builder hiển thị tải và lỗi đọc. Lỗi ghi hiện qua SnackBar, lỗi đồng bộ do Shell báo. |
| 06 | Lifecycle | Stream được tạo bằng `late final` trong State và nghe bởi `StreamBuilder`. Trang không khai báo `initState/dispose`; dialog dùng biến tên và `GlobalKey<FormState>` cục bộ. |
| 07 | UI tree | `RoadmapScreen` chứa danh sách môn và form tạo hoặc đổi tên. `_SubjectRoadmap` mở thành route riêng. |
| 08 | Tương tác | Bấm tên môn để mở chi tiết. Menu của dòng mở **Đổi tên môn học** hoặc **Xóa môn học**. |
| 09 | Theme | `CircleAvatar` đọc màu từ `subject.color`. Mã màu sai dùng màu mặc định `#5685F7`. |
| 10 | Data flow | Form hợp lệ gọi `saveSubject` khi tạo và `updateSubject` khi đổi tên. Tạo thành công mở chi tiết, đổi tên cập nhật dòng theo cùng UUID. |
| 11 | State | Danh sách ở stream, tên đang nhập là biến trong dialog. Nếu cần chọn chung một môn giữa Roadmap và Mindmap, đưa `selectedSubjectId` lên Shell hoặc controller dùng chung; đọc bản ghi theo ID. |
| 12 | Impact | Xóa môn ghi UUID vào `subject_deletions`. Server dùng cờ `subjects.is_deleted` để ẩn môn và nội dung liên quan. |
| 13 | Rebuild | Bảng môn đổi thì builder tạo lại cây danh sách. Gõ tên ở dialog chưa ghi bảng, vì vậy stream chưa phát. Dùng Track Widget Builds và đối chiếu lúc gõ với lúc Save. |
| 14 | Null safety và JSON | `_pullSubjects` xử lý `deleted: true` trước khi đọc tên và màu. Bản local đang chờ sửa hoặc xóa được giữ cho lần đồng bộ tiếp theo. |
| 15 | Navigation | `_openSubject` dùng `push`, nên Back ở chi tiết trả về danh sách. Back ở dialog đóng form, còn Back tại tab gốc không quay lại tab trước. |
| 16 | Data passing | Shell truyền `database` vào `RoadmapScreen`. `_openSubject` truyền `Subject` và `database` qua constructor `_SubjectRoadmap`. |
| 17 | Local storage | Drift ghi xóa môn và dọn nhánh lộ trình, Mindmap của môn trong cùng giao dịch. `watchSubjects()` phát danh sách mới sau khi ghi. |
| 18 | Nợ kỹ thuật | Tạo môn xuất hiện ở cả Roadmap và Mindmap với cách validate khác nhau. Nếu mở rộng, dùng một dialog và hàm tạo môn dùng chung, giữ điều hướng riêng cho từng trang. |
| 19 | Live-code xác nhận | Mở **Xóa môn học**, kiểm tra xác nhận nhắc đến Lộ trình và Mindmap, rồi bấm **Hủy** để kiểm tra môn vẫn còn. |
| 20 | Async/await | Bỏ `await saveSubject` có thể mở chi tiết trước khi ghi môn xong và bỏ lọt lỗi ghi. `mounted` sau await ngăn mở route từ context đã bị gỡ. |
| 21 | Thử làm hỏng | Tạm bỏ kiểm tra `formKey.currentState!.validate()`. Tên rỗng có thể đi tới bước ghi và bị Drift từ chối. Khôi phục validate để hiện lỗi ngay trong form. |
| 22 | Live-code debounce | Tên môn hiện chỉ validate local. Nếu thêm ô tìm danh sách, debounce `onChanged` 500 ms và lọc theo tên ở Drift hoặc API tìm kiếm được bổ sung. |
| 23 | Auth/session | Có thể thêm, đổi tên hoặc xóa môn offline. Khi đồng bộ, backend kiểm tra quyền sở hữu theo JWT. |
| 24 | Bộ nhớ | Subscription thuộc `StreamBuilder`. Form không tạo `TextEditingController` riêng. `late final` ổn định stream qua các lần build của cùng State. |
| 25 | Pagination | Server hiện trả toàn bộ môn theo tên. Thêm cursor theo `name,id`, đổi `_pullSubjects` để hợp nhất từng trang và dùng builder. Đồng bộ Roadmap/Mindmap cần vẫn xử lý đủ các môn liên quan. |

## 5. Lộ trình — Chi tiết môn

[`_SubjectRoadmap` và cây](../frontend/lib/screens/roadmap_screen.dart#L185) · [Form nhánh](../frontend/lib/screens/roadmap_screen.dart#L579) · [Query và lưu nhánh](../frontend/lib/data/app_database.dart#L219) · [Đồng bộ lộ trình](../frontend/lib/data/sync_service.dart#L180)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | `Scaffold → AppBar → StreamBuilder → _RoadmapList`. Header có nút thêm nhánh và thẻ tiến độ. Mỗi dòng có trạng thái và menu thao tác. |
| 02 | Tối ưu layout | `_visibleBranches` làm phẳng cây bằng ngăn xếp, rồi `ListView.builder` dựng từng hàng. Nhánh đã thu gọn ẩn các dòng con. |
| 03 | Overflow | Ghi chú ở tile có `maxLines: 3` và `TextOverflow.ellipsis`. Form có `scrollable: true`. Lề cây giới hạn độ sâu hiển thị ở 4. `Text(node.title)` chưa giới hạn dòng; thử title dài khi có hai icon bên phải. |
| 04 | Responsive | Chi tiết dùng một cột, giới hạn 920 px. Lề thụt của nhánh dừng ở bốn cấp để chừa chỗ đọc trên màn hình hẹp. |
| 05 | Nguồn dữ liệu và lỗi | `watchRoadmap(subject.id)` lọc môn và sắp theo `sortOrder`. Builder hiện lỗi đọc; `_editNode` bắt lỗi ghi và hiện SnackBar. HTTP 500 đi qua luồng đồng bộ ở Shell khi quay về màn hình chính. |
| 06 | Lifecycle | `_subject` và `_nodes` là stream ổn định qua các lần build. `_collapsed` giữ ID nhánh thu gọn. Form có State riêng. |
| 07 | UI tree | `_SubjectRoadmap` chứa `_RoadmapProgress` và `_RoadmapBranchTile`. `_RoadmapNodeDialog` giữ dữ liệu form và trả về một `RoadmapNode`. |
| 08 | Tương tác | Bấm dòng để sửa. Menu có sửa, thêm con hoặc xóa. Nút thu gọn và mở rộng đổi `_collapsed`. |
| 09 | Theme | `_RoadmapProgress` dùng màu nền `primaryContainer`. `_RoadmapBranchTile` chọn biểu tượng theo trạng thái. |
| 10 | Data flow | Form trả `RoadmapNode`. `saveRoadmapEdit` kiểm tra cha, lưu nhánh và đặt `isSynced = false`. Stream cập nhật cây và tiến độ. |
| 11 | State | Dữ liệu nghiệp vụ ở Drift, UI giữ `_collapsed` cục bộ. Nếu cần nhớ cây đã mở khi đổi trang, đặt state theo `subjectId` trong controller dùng chung hoặc lưu tùy chọn riêng. |
| 12 | Impact | Hạn học `dueAt` được chọn hoặc bỏ trong form, hiển thị trên dòng và gửi qua API dưới dạng ISO 8601. |
| 13 | Rebuild | Thu/mở dùng `setState`, dựng lại builder/cây đang nhìn thấy. Ghi ghi chú kích hoạt stream theo môn. `ValueKey(node.id)` giữ identity nhưng không ngăn rebuild. Dùng DevTools ghi hai lần thao tác để so sánh. |
| 14 | Null safety và JSON | `_pullRoadmap` dùng mặc định cho `note/status/sortOrder`, chấp nhận `parentId/dueAt` rỗng và xử lý `deleted: true` trước khi đọc nội dung. |
| 15 | Navigation | Trang được `push` từ danh sách. Back trong dialog đóng dialog. Back ở chi tiết pop route, đưa về danh sách môn đã mở trước đó. |
| 16 | Data passing | Route nhận môn ban đầu và database. `watchSubject` cập nhật tên trên AppBar, `watchRoadmap` lấy cây theo ID môn. |
| 17 | Local storage | `deleteRoadmapNode` lưu lệnh xóa và đưa con trực tiếp lên gốc trong cùng giao dịch. Đồng bộ bỏ lệnh sau khi server xác nhận. |
| 18 | Nợ kỹ thuật | Form loại nhánh đang sửa và hậu duệ khỏi danh sách cha. Drift và backend kiểm tra tổ tiên để ngăn vòng lặp khi lưu. |
| 19 | Live-code xác nhận | Xóa một nhánh có con và kiểm tra nhánh con chuyển lên gốc. Hủy hộp thoại thì cây giữ nguyên. |
| 20 | Async/await | `_editNode` chờ `saveRoadmapEdit` để bắt lỗi ghi. Guard `mounted` bảo vệ State nếu route đã đóng. |
| 21 | Thử làm hỏng | Thử gửi `PUT` với `parentId` là một hậu duệ của nhánh. Server trả `400` với mã `01207`. |
| 22 | Live-code debounce | Gõ ghi chú chỉ đổi biến trong form. Nếu thêm tìm chủ đề, dùng debounce 500 ms cho query tìm; giữ Save là thao tác xác nhận ghi. |
| 23 | Auth/session | Chi tiết đọc local. Khi đồng bộ, các API GET, PUT và DELETE kiểm tra JWT, quyền sở hữu và môn của nhánh. |
| 24 | Bộ nhớ | `StreamBuilder` hủy đăng ký khi route pop. `_collapsed` nằm trong State và được thu gom cùng State. Màn này không tạo Timer hay controller ngoài form. |
| 25 | Pagination | Phân trang theo môn với thứ tự ổn định `sortOrder,id`. Với cây, cân nhắc tải gốc trước và tải con khi mở, hoặc ghép mọi trang theo `parentId` trước khi render. Tiến độ toàn môn cần tổng đếm riêng. |

## 6. Mindmap

[MindmapScreen và các nhánh giao diện](../frontend/lib/screens/mindmap_screen.dart) · [Thao tác SQLite](../frontend/lib/data/app_database.dart#L159) · [Đồng bộ Mindmap](../frontend/lib/data/sync_service.dart#L167) · [MindmapController](../backend/src/main/java/com/duy/studyplanner/api/mindmap/MindmapController.java)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | Desktop có hai `Wrap` cho thanh thao tác, dropdown môn và `Expanded → InteractiveViewer → Stack/CustomPaint`. Mobile dùng `ListView` và Card chỉ xem. Đổi màu thẻ, viền hoặc đường nối trong `_MindmapPainter.paint`. |
| 02 | Tối ưu layout | Mobile dùng `ListView(children: ...)` với vòng lặp card. Desktop là canvas tọa độ tuyệt đối nên `ListView.builder` không thay thế trực tiếp được. Dùng builder cho danh sách mobile, hoặc giới hạn vùng vẽ/hit target theo viewport trên desktop nếu dữ liệu lớn. |
| 03 | Overflow | Thanh nút dùng `Wrap`; nhãn thẻ đang chọn có ellipsis. Painter đặt `maxLines: 2`, `ellipsis: '…'` và giới hạn chiều rộng tiêu đề. Dropdown desktop chưa giới hạn tên dài riêng, nên vẫn cần thử với tên môn dài. |
| 04 | Responsive | `_isDesktop` cho sửa trên Windows hoặc Web rộng ít nhất 760 px. Android vẫn chỉ xem khi xoay ngang. Đổi điều kiện này nếu muốn hỗ trợ thêm nền tảng, rồi kiểm tra kéo thả và giới hạn kích thước canvas. |
| 05 | Nguồn dữ liệu và lỗi | `watchSubjects` và `watchMindmap(subjectId)` đọc SQLite. Bản mobile có thông báo lỗi snapshot; desktop đang dùng danh sách rỗng khi không có dữ liệu. Lỗi HTTP khi đồng bộ do `AppShell._sync` báo. |
| 06 | Lifecycle | State tạo stream môn bằng `late final` và cache stream từng môn. `StreamBuilder` quản lý nghe/hủy. Trang không có `initState/dispose` riêng; controller của `InteractiveViewer` được widget quản lý. |
| 07 | UI tree | `_buildMobileMindmap`, `_canvas`, các hàm dialog và `_MindmapPainter` đã tách theo vai trò. Có thể tách toolbar hoặc editor thành widget riêng nếu muốn giới hạn rebuild khi kéo. |
| 08 | Tương tác | Tap thẻ đổi `_selectedNodeId`. **Chi tiết / Sửa** gọi `_editNode`, **Nối vào…** gọi `_connectNode`, **Xóa thẻ** gọi `_deleteNode`. Kéo thẻ lưu vị trí tại `_finishDrag`. |
| 09 | Theme | Button và dropdown dùng theme Material. Màu nền lưới, viền, thẻ chọn, chữ và đường nối được đặt trực tiếp trong painter. Đổi giá trị `Paint.color` hoặc truyền màu từ theme vào painter. |
| 10 | Data flow | **Nối vào…** → dialog chọn cha hợp lệ → `updateMindmapNode` lưu `parentId` và đặt cờ chờ sync → Drift phát → painter vẽ đường mới. Xóa thêm bản ghi vào hàng đợi và tách con; sync gửi DELETE sau. |
| 11 | State | `_subjectId/_selectedNodeId/_draggingNode` dùng `setState`; dữ liệu thẻ ở Drift. Nếu cần chia sẻ môn đang chọn, đưa ID lên Shell. Giữ vị trí kéo tạm trong editor. |
| 12 | Impact | Ví dụ thêm màu thẻ lưu lâu dài. Thêm migration/entity/DTO → cột Drift và model sinh → `_pushMindmap/_pullMindmap` → form, painter và Card mobile. Nếu chỉ đổi màu thẻ đang chọn, sửa painter. |
| 13 | Rebuild | Kéo gọi `setState` theo từng update, nên toolbar và canvas có thể build lại. Painter nhận danh sách mới và có thể repaint; build và paint là hai phép đo khác nhau. Dùng Track Widget Builds và Repaint Rainbow để kiểm tra. |
| 14 | Null safety và JSON | `_pullMindmap` bắt buộc `result` là danh sách, rồi cast `id/subjectId/title`. `parentId` có thể null, `content` mặc định rỗng, tọa độ thiếu dùng 100. Thiếu `result` làm sync lỗi và tránh coi đó là danh sách rỗng. |
| 15 | Navigation | Mindmap là tab của `IndexedStack`. Dialog sửa/nối/xóa dùng `showDialog` và `Navigator.pop` để trả kết quả. Back khi có dialog chỉ đóng dialog. |
| 16 | Data passing | `MindmapScreen({required database})` nhận DB. Môn chọn cung cấp `subjectId` cho stream; thẻ đã chọn truyền cho `_editNode`, `_connectNode` hoặc `_deleteNode`. |
| 17 | Local storage | Tạo dùng `saveMindmapNode`. Sửa/nối/kéo dùng `updateMindmapNode`. Xóa dùng `deleteMindmapNode`, ghi hàng đợi và tách con trong giao dịch. Stream theo môn phát lại sau khi ghi. |
| 18 | Nợ kỹ thuật | Mỗi lần kéo tạo danh sách vẽ mới và có thể dựng lại toàn editor. Có thể cô lập drag preview trong lớp canvas có notifier, thêm vùng repaint riêng và đo trước/sau. |
| 19 | Live-code xác nhận | **Xóa thẻ** đã có `AlertDialog<bool>` trong `_deleteNode`. `Navigator.pop(context, true)` mới dẫn đến xóa DB; Back hoặc Hủy trả `null` và thoát. |
| 20 | Async/await | Bỏ `await deleteMindmapNode` làm UI bỏ chọn trước khi giao dịch xóa hoàn tất. Guard `mounted` ngăn gọi `setState` khi editor đã bị gỡ trong lúc chờ. |
| 21 | Thử làm hỏng | Tạm bỏ dòng cập nhật các node con về `parentId = null` trong giao dịch xóa local. Dự kiến node con giữ ID cha đã mất, mobile không hiện tên cha, canvas mất đường nối nhưng dữ liệu vẫn treo. Khôi phục cập nhật và chạy test xóa Mindmap. |
| 22 | Live-code debounce | Ô tiêu đề/nội dung cập nhật biến form local. Nếu thêm tìm thẻ, debounce 500 ms trên query tìm kiếm; đặt Timer ở State sở hữu ô tìm và hủy lúc dispose. |
| 23 | Auth/session | Lưu/kéo/xóa cục bộ chạy offline. Sync gửi Bearer cho GET/PUT/DELETE. HTTP 401 hiện lỗi ở Shell; HTTP 410 khi gửi thẻ đã bị xóa là trường hợp riêng được `SyncService` xử lý để bỏ thẻ local. |
| 24 | Bộ nhớ | Các `StreamBuilder` hủy đăng ký khi đổi môn hoặc bị gỡ. `_streams` giữ tham chiếu theo ID tới khi State kết thúc, nên đo số entry nếu người dùng mở rất nhiều môn. Không có Timer trong editor. |
| 25 | Pagination | Mobile có thể builder theo trang. Canvas cần tập node đủ để vẽ cạnh hoặc tải theo nhánh/vùng. `_pullMindmap` hiện đối chiếu ID từ danh sách đầy đủ và xóa bản local vắng mặt; phải thu đủ các trang hoặc dùng dấu xóa riêng trước khi dọn local. |

## 7. Tập trung

[FocusScreen và bộ đếm](../frontend/lib/screens/focus_screen.dart) · [Thông báo cục bộ](../frontend/lib/data/notification_service.dart#L43)

| # | Chủ đề | Câu trả lời |
| --- | --- | --- |
| 01 | Blind-test UI | `Center → SingleChildScrollView → ConstrainedBox → Card` chứa mốc nhanh, đồng hồ và các nút điều khiển. Chạm đồng hồ để mở bộ chọn. |
| 02 | Tối ưu layout | `Wrap` xếp năm mốc nhanh và tự xuống hàng. `CupertinoPicker.builder` dựng các giá trị giờ, phút, giây theo nhu cầu. |
| 03 | Overflow | Màn hình cuộn khi thiếu chiều cao. Đồng hồ dùng `FittedBox` để co chữ khi thiếu chiều ngang. Hộp thoại có ba cột co theo chiều rộng. |
| 04 | Responsive | Card giới hạn rộng 560 px. Các bánh cuộn nhận thao tác vuốt, lăn chuột hoặc kéo bằng chuột. |
| 05 | Nguồn dữ liệu và lỗi | Đồng hồ đọc `_remaining`, `_duration` và `_running` trong State. `_updateNotification` xử lý lỗi plugin để bộ đếm vẫn chạy. |
| 06 | Lifecycle | Mặc định 30 phút. **Bắt đầu** tạo Timer. **Tạm dừng**, **Đặt lại**, hết giờ và `dispose` hủy Timer. |
| 07 | UI tree | `_FocusDurationDialog` có ba `_DurationWheel`, mỗi cột chứa một `CupertinoPicker`. Dialog trả tổng số giây khi bấm **Áp dụng**. |
| 08 | Tương tác | Chip chọn 10, 15, 20, 30 phút hoặc 1 giờ. Chạm đồng hồ để đặt giờ, phút, giây. Khi đang đếm, có thể tạm dừng hoặc đặt lại trước khi chọn thời lượng mới. |
| 09 | Theme | Tiêu đề và icon dùng theme Material. Đồng hồ dùng `FontFeature.tabularFigures()` để các chữ số có chiều rộng đều nếu font hỗ trợ. |
| 10 | Data flow | **Bắt đầu** tạo Timer và gửi yêu cầu đặt thông báo. Mỗi tick tính số giây còn lại từ số tick của Timer, rồi `_clockLabel` tạo chuỗi `HH:mm:ss`. |
| 11 | State | Dùng `setState` cục bộ. Nếu cần hiển thị đồng hồ ở nhiều tab hoặc duy trì qua thay đổi bố cục, đưa thời điểm kết thúc và trạng thái vào controller do AppShell hoặc app gốc sở hữu. |
| 12 | Impact | Mốc nhanh nằm trong `_presets` theo phút. Bộ chọn tùy chỉnh trả thời lượng từ 1 giây đến 23 giờ 59 phút 59 giây. |
| 13 | Rebuild | Mỗi tick dựng lại `FocusScreen.build`; tách widget bằng hàm chưa đủ để cô lập. Có thể dùng `ValueListenableBuilder` chỉ quanh đồng hồ và theo dõi số lần build trước/sau. |
| 14 | Null safety và JSON | Trang không parse JSON. `Timer?` được xử lý bằng `?.cancel()`. Nếu thêm DTO lịch sử, xác định trường thời lượng bắt buộc và cách xử lý trường tùy chọn trong parser riêng. |
| 15 | Navigation | Tab Tập trung không dùng `push`. Khi chuyển tab trong cùng `IndexedStack`, State tiếp tục tồn tại. Khi State bị gỡ khỏi cây, `dispose` hủy Timer. |
| 16 | Data passing | Shell truyền `NotificationService` qua constructor. Chip hoặc dialog chuyển thời lượng theo giây cho `_choose`. |
| 17 | Local storage | Bộ đếm lưu trong bộ nhớ. Plugin lên lịch một thông báo theo thời điểm kết thúc; app không đọc thông báo đó để khôi phục đồng hồ khi mở lại. |
| 18 | Nợ kỹ thuật | Timer chạy độc lập với plugin. Các yêu cầu đặt và hủy thông báo được thực hiện theo thứ tự, kể cả khi thao tác liên tiếp. |
| 19 | Live-code xác nhận | Đặt thời lượng tùy chỉnh, bắt đầu rồi tạm dừng. Bấm **Đặt lại** để kiểm tra đồng hồ trở về thời lượng đã chọn. |
| 20 | Async/await | `_updateNotification` xếp yêu cầu vào một chuỗi Future. Lỗi đặt hoặc hủy thông báo được xử lý trong từng yêu cầu. |
| 21 | Thử làm hỏng | Tạm bỏ `_timer?.cancel()` trong `dispose`. Dự kiến chạy đồng hồ rồi đăng xuất có thể gây `setState() called after dispose()` ở tick kế tiếp. Khôi phục cancel và thử lại. |
| 22 | Live-code debounce | Chọn chip hiện xử lý ngay, không gọi API. Nếu bổ sung ô tìm lịch sử phiên, gắn debounce 500 ms cho ô tìm; giữ các thao tác Bắt đầu/Tạm dừng tức thời. |
| 23 | Auth/session | Bộ đếm chạy cả khi offline. Trang không gửi token; nếu sau này đồng bộ lịch sử thì dùng `ApiClient` chung và chính sách 401 tập trung. |
| 24 | Bộ nhớ | Bằng chứng hủy Dart Timer nằm trong `dispose`. Thông báo OS được hủy ở Tạm dừng/Đặt lại; `dispose` chỉ hủy Timer. Dùng widget test với đồng hồ giả để kiểm tra không còn tick sau khi gỡ widget. |
| 25 | Pagination | Mốc nhanh và đồng hồ không cần phân trang. Ba bánh cuộn dựng giá trị bằng builder. |

## Mẫu live-code và cách kiểm chứng

### 19. Xác nhận trước khi chạy logic cũ

```dart
Future<bool> confirmAction(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Có chắc chắn không?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Có'),
        ),
      ],
    ),
  );
  return accepted == true;
}
```

Trong callback, dùng `if (!await confirmAction(context) || !context.mounted) return;` rồi gọi logic cũ. Nếu State có cờ đang chạy, kiểm tra cờ lại sau khi dialog đóng. Kiểm thử cả **Có**, **Hủy** và **Back**.

### 22. Debounce 500 ms và bỏ phản hồi cũ

Mẫu này giả sử đã có hàm `searchSubjects(query)` trả danh sách môn và State đã khai báo `_results`, `_error`. Gắn `onChanged: _onSearchChanged` vào ô tìm kiếm.

```dart
Timer? _debounce;
int _searchVersion = 0;

void _onSearchChanged(String input) {
  _debounce?.cancel();
  final query = input.trim();
  final version = ++_searchVersion;

  _debounce = Timer(const Duration(milliseconds: 500), () async {
    try {
      final rows = await searchSubjects(query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = rows;
        _error = null;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() => _error = 'Không thể tìm kiếm.');
    }
  });
}

@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

Import `dart:async` và gộp phần hủy Timer vào `dispose` sẵn có. `cancel()` hủy lần chờ kế tiếp; số phiên bản bảo vệ UI trước request cũ đã bắt đầu. Dùng test với `pump` qua mốc 499 ms và 500 ms rồi thử cho hai phản hồi về ngược thứ tự.

### 13, 21 và 24. Kiểm tra rebuild, hồi quy và tài nguyên

- **Rebuild.** Bật Track Widget Builds trong DevTools, thực hiện một thao tác và xem widget nào build. Với canvas, kiểm tra thêm repaint. So sánh cùng dữ liệu và thao tác trước/sau khi thay cấu trúc.
- **Thử làm hỏng.** Thực hiện từng thay đổi trên bản sao hoặc nhánh thử nghiệm. Chạy đúng kịch bản ở dòng 21, ghi lỗi quan sát được rồi khôi phục và chạy lại. Bảng trên mô tả kết quả dự kiến.
- **Lifecycle.** Kiểm tra đóng dialog, Back, đăng xuất và đổi tab. Dùng widget test hoặc DevTools Memory để kiểm tra Timer/subscription còn hoạt động sau khi State bị gỡ. Khi đổi tab trong `IndexedStack`, việc State còn tồn tại là hành vi được thiết kế.

Các test hiện có minh họa đăng ký khi storage lỗi, vòng đời dialog, mở đúng môn, thu gọn cây, cập nhật nhánh và thử lại lệnh xóa. Chạy `flutter test` từ `frontend/`. [Widget tests](../frontend/test/dialog_lifecycle_test.dart) · [Đồng bộ Lộ trình](../frontend/test/roadmap_sync_test.dart) · [Đồng bộ Mindmap](../frontend/test/mindmap_sync_test.dart)

### 23 và 25. Mở rộng dùng chung

- **Hết phiên.** Xử lý 401 của các API cần đăng nhập ở một điểm dùng chung. Gọi callback về controller phiên để xóa phiên và cập nhật app gốc, giữ lỗi sai mật khẩu ở form. Kiểm tra nhiều request 401 đến cùng lúc và dữ liệu offline đang chờ đồng bộ.
- **Load-more.** Dùng cursor ổn định từ server, giữ `items/nextCursor/loadingMore/error` cho từng bộ lọc, chống request trùng và bỏ phản hồi của bộ lọc cũ. Hiển thị hàng tải thêm hoặc nút thử lại. Nếu màn hình đọc Drift, nhập dữ liệu theo từng trang và cập nhật stream để vẫn xem được offline.
