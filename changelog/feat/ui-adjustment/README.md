# Changelog - feat/ui-adjustment

## 2026-02-08
- Hoàn thiện web host UI tách thành asset riêng: `assets/web_host/index.html`, `assets/web_host/console.css`, `assets/web_host/console.js`.
- Bổ sung web quản lý tri thức riêng: `assets/web_host/manager.html`, `assets/web_host/manager.js`.
- Trang manager chuyển sang chế độ **chỉ xem theo mục KDOC** (read-only tài liệu), không chỉnh sửa trực tiếp nội dung.
- Giữ luồng test truy vấn tri thức trên manager (`query`, `top_k`, hiển thị kết quả từ `POST /api/search`).
- Cải thiện hiển thị kết quả tìm kiếm: badge `score` đổi màu theo độ khớp (cao/trung bình/thấp).
- Bổ sung modal popup đồng bộ style cho các thao tác xác nhận/nhập liệu trên web console (thay `confirm/prompt` mặc định).
- Nâng cấp UX quản lý tài liệu: folder + kéo thả tài liệu, tag CRUD, import/export toàn bộ dữ liệu JSON.
- Đồng bộ trạng thái host/tài liệu, định dạng thời gian và số ký tự dễ đọc hơn.
- Cập nhật static serving cho web host trong Flutter: `lib/capabilities/web_host/local_web_host_service.dart`.
- Cập nhật MCP/chat/protocol liên quan để ổn định luồng gọi tool và debug log:
  - `lib/capabilities/mcp/mcp_server.dart`
  - `lib/capabilities/protocol/mqtt_protocol.dart`
  - `lib/capabilities/protocol/websocket_protocol.dart`
  - `lib/capabilities/voice/default_session_coordinator.dart`
  - `lib/features/chat/infrastructure/repositories/chat_repository_impl.dart`
  - `lib/features/home/application/state/home_cubit.dart`
- Cập nhật UI app Flutter liên quan điều hướng/settings/MCP page:
  - `lib/presentation/pages/home_page.dart`
  - `lib/presentation/pages/mcp_flow_page.dart`
  - `lib/presentation/widgets/home/home_camera_overlay.dart`
  - `lib/presentation/widgets/home/home_footer.dart`
  - `lib/presentation/widgets/home/home_settings_sheet.dart`
  - `lib/routing/app_router.dart`
- Loại bỏ `lib/presentation/pages/permission_sheet_content.dart`.
- Cập nhật cấu hình asset trong `pubspec.yaml`.
- Bổ sung test KDOC: `test/capabilities/mcp/kdoc_validation_test.dart`.

## Verify
- `flutter analyze`: PASS.
