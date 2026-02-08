# Changelog - feat/ui-adjustment

## 2026-02-08 (MCP Local-Only Image Retrieval + Non-Intrusive Chat Display)
- Khối chat related images chạy qua MCP tool `self.knowledge.search_images`, ưu tiên ảnh upload nội bộ từ web host trên thiết bị.
- Khóa lọc URL ảnh: chỉ chấp nhận `/api/documents/image/content?id=...` trên local web host (`127.0.0.1:<port>`), loại bỏ URL ngoài.
- Bổ sung fallback context cho query ảnh chung chung (ví dụ: `cho tôi hình ảnh`) để tiếp tục bám sát ngữ cảnh sản phẩm trước đó.
- Tăng log debug MCP image flow (`mcp_tool_call`, `mcp_tool_success`, `mcp_tool_error`, `related_images_drop_non_local`).
- Cải thiện normalize alias tìm kiếm (`chabi -> chavi`) cho cả MCP search và chat query normalization.
- Điều chỉnh Chat UI state: block `related_images` chỉ hiển thị khi có dữ liệu; nếu không có ảnh thì xóa block, không ảnh hưởng nội dung trả lời của agent.

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

## 2026-02-08 (Image Upload MVP For Web Console)
- Bổ sung lưu trữ ảnh theo từng tài liệu, có persistence sau khi restart app:
  - `lib/capabilities/web_host/document_image_store.dart`
- Mở rộng API web host cho ảnh (không thay đổi API cũ):
  - `POST /api/documents/image`
  - `GET /api/documents/images`
  - `GET /api/documents/image/content`
  - `DELETE /api/documents/image`
- Giữ tương thích endpoint cũ:
  - `GET /api/documents`
  - `GET /api/documents/content`
  - `POST /api/documents/text`
  - `DELETE /api/documents`
  - `POST /api/search`
- Đồng bộ vòng đời ảnh với tài liệu:
  - Hỗ trợ đổi tên tài liệu qua payload `old_name` khi lưu để remap ảnh.
  - Xóa toàn bộ tài liệu sẽ dọn metadata/file ảnh liên quan.
- Nâng cấp UI web console:
  - Upload ảnh theo tài liệu (click + drag/drop).
  - Hiển thị tiến trình/trạng thái upload.
  - Gallery thumbnail theo tài liệu đang chọn.
  - Xóa ảnh bằng confirm modal đồng bộ style.
- Nâng cấp manager read-only:
  - Thêm gallery ảnh chỉ xem theo tài liệu.
- Bổ sung test cho image store:
  - `test/capabilities/web_host/document_image_store_test.dart`

## Verify (Image Upload MVP)
- `flutter analyze`: PASS.
- `flutter test test/capabilities/web_host/document_image_store_test.dart`: FAIL (môi trường local thiếu cấu hình OpenCV tương thích cho `dartcv4`, lỗi CMake `OpenCV_FOUND=FALSE`).

## 2026-02-08 (Chat Related Images Integration)
- Mở rộng domain chat để hỗ trợ block ảnh liên quan:
  - `lib/features/chat/domain/entities/related_chat_image.dart`
  - `lib/features/chat/domain/entities/chat_message.dart` (thêm `ChatMessageType.relatedImages`, `id`, `relatedImages`, `relatedQuery`)
- Bổ sung use case và wiring DI:
  - `lib/features/chat/application/usecases/get_related_images_for_query_usecase.dart`
  - `lib/di/modules/feature_module.dart`
- Mở rộng repository contract + implementation để lấy ảnh liên quan theo query:
  - `lib/features/chat/domain/repositories/chat_repository.dart`
  - `lib/features/chat/infrastructure/repositories/chat_repository_impl.dart`
  - Luồng: `POST /api/search` -> `GET /api/documents/images?name=...` -> gộp/dedup/sort/limit.
- Gắn vào ChatCubit:
  - trigger load ảnh khi có user query (text/STT),
  - thêm log ngữ cảnh (`query`, `count`, `latency`, lỗi),
  - upsert một message block ảnh riêng trong timeline.
- Cập nhật UI chat render gallery ảnh:
  - `lib/features/chat/presentation/widgets/chat_message_list.dart`
  - hiệu ứng show/hide bằng `AnimatedSwitcher` + `AnimatedSize`,
  - tap thumbnail mở preview zoom.
- Cập nhật home page để chỉ lấy message text cho transcript footer:
  - `lib/presentation/pages/home_page.dart`
- Bổ sung test:
  - `test/features/chat/chat_repository_related_images_test.dart`
  - `test/features/chat/chat_message_list_widget_test.dart`

## Verify (Chat Related Images)
- `flutter analyze`: PASS.
- `flutter test`: FAIL do môi trường local bị chặn native build `dartcv4/OpenCV` (`OpenCV_FOUND=FALSE`, CMake), không phải lỗi logic phần chat ảnh.
