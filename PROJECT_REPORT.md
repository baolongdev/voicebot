# 1) Tổng quan dự án
- Mục tiêu app: Client Flutter cho trợ lý giọng nói XiaoZhi, stream âm thanh Opus qua WebSocket (MQTT/UDP chuẩn bị sẵn) tới backend XiaoZhi; cấu hình server/OTA rồi trò chuyện rảnh tay.
- Đối tượng người dùng: Người dùng kỹ thuật/lab cần cấu hình thiết bị/OTA và giao tiếp giọng nói với backend XiaoZhi trên Android/Windows.
- Luồng chính: mở app → (luồng V2) xin quyền → trang Home (v1 hoặc V2 dashboard) → điền form server, gọi OTA lấy token/endpoint → nếu có activation thì xem mã, tiếp tục → trang Chat, auto start listening/streaming.

# 2) Những gì đã làm được (Done)
- [x] Quyền truy cập (mic + nhiều quyền khác) với flow v1/v2 (`lib/system/permissions/**`, `lib/presentation/pages/v2_permissions_page.dart`).
- [x] Form cấu hình server XiaoZhi/self-host + validate + gọi OTA, lưu config in-memory (`lib/features/form/**`, `lib/system/ota/ota.dart`).
- [x] OTA parse WebSocket/MQTT/activation/firmware, lưu device identity vào secure storage (`lib/core/system/ota/model/**`, `lib/system/ota/ota.dart`).
- [x] Chat WebSocket: handshake hello/listen, encode Opus 60ms, decode & play, tự retry 2s, hiển thị message/lỗi (`lib/features/chat/**`, `lib/capabilities/voice/**`, `lib/capabilities/protocol/websocket_protocol.dart`).
- [x] UI kích hoạt hiển thị mã (`lib/features/activation/presentation/pages/activation_page.dart`).
- [x] Luồng Home v1 dẫn tới form (`lib/features/home/presentation/**`).
- [x] UI thử nghiệm V2 Home dashboard (pin/mạng/âm lượng/Wi‑Fi scan) + nút kết nối chat/hiển thị transcript (`lib/presentation/pages/v2_home_page.dart`).
- [x] Auth module (login/profile/secure storage) bằng Bloc nhưng đang tắt qua cấu hình (`lib/features/auth/**`, `lib/core/config/app_config.dart`).

# 3) Những gì đang làm dở (In progress)
- [ ] V2 Home trải nghiệm kết nối chat/OTA còn tạm thời (tự check OTA khi thiếu config, chưa hoàn thiện luồng success/error) — `lib/presentation/pages/v2_home_page.dart`.
- [ ] Emotion picker/CTA footer ở V2 Home chưa có xử lý hành động (onSelect bị bỏ trống) — `lib/presentation/pages/v2_home_page.dart`.
- [ ] Wi‑Fi scan/kết nối phụ thuộc plugin, thiếu xử lý lỗi/permission sâu và feedback sau khi kết nối — `lib/presentation/pages/v2_home_page.dart`.
- [ ] MQTT/UDP code có sẵn nhưng không được chọn/wired từ Settings/ChatConfig — `lib/capabilities/protocol/mqtt_protocol.dart`, `lib/features/form/infrastructure/repositories/settings_repository_impl.dart`.
- [ ] OTA upgrade flow có API nhưng không gọi từ UI; chưa có xác thực firmware — `lib/system/ota/ota.dart`.
- [ ] Unit test hiện có (form/permission/ota) chưa được kiểm tra trạng thái pass; cần chạy/sửa — `test/**`.

# 4) Những gì chưa làm (TODO)
- [ ] Persist WebSocket/MQTT config và token sau OTA vào secure storage (hiện chỉ in-memory `SettingsRepositoryImpl`).
- [ ] Backoff/heartbeat/close logic cho Chat retry; xử lý khi thiếu token/URL tốt hơn.
- [ ] Giao diện mic toggle/VU meter, speak indicator, stop listening on dispose cho Chat.
- [ ] Hoàn thiện selection transport MQTT/UDP theo `transportType`; test end-to-end.
- [ ] Hạn chế quyền bắt buộc (hiện yêu cầu camera/photos/bluetooth/wifi) và thêm xử lý permanently denied + mở settings.
- [ ] Bổ sung logging/telemetry cấu trúc cho connect/hello/listen/audio stats.
- [ ] Bảo vệ OTA: checksum/hash/size, skip upgrade nếu thiếu URL; prompt người dùng.
- [ ] Viết thêm test: ChatConfigProvider, SessionCoordinator (speaking → resume), OTA parsing lỗi.
- [ ] Sắp xếp lại nhóm màn hình V2 vào module riêng, chuẩn hoá naming Page/Sheet/Widget.

# 5) Kiến trúc & kỹ thuật hiện tại
- State management: Bloc cho auth/form/permissions (`lib/features/auth/presentation/state`, `lib/features/form/presentation/state`, `lib/system/permissions/permission_notifier.dart`); ChangeNotifier cho chat (`lib/features/chat/application/state/chat_controller.dart`); setState cho V2 UI.
- Routing: `go_router` với guard auth/permission + cờ `AppConfig.useNewFlow` (`lib/routing/app_router.dart`, `lib/routing/routes.dart`).
- Networking: `http` client; WebSocket native; MQTT client + UDP (pointycastle AES-CTR) chưa wired.
- Model/DTO: DTO mapper cho auth (`lib/features/auth/infrastructure/models/**` + mapper), OTA models (`lib/core/system/ota/model/**`), ChatConfig/domain entities.
- Local storage: `flutter_secure_storage` cho auth session & OTA identity; Settings repo hiện in-memory (`lib/features/form/infrastructure/repositories/settings_repository_impl.dart`).
- Quy ước folder: Clean Architecture: `core/` (config/errors/logging/permissions/audio), `capabilities/` (protocol/audio/voice), `features/<feature>/` tách domain/application/presentation/infrastructure, `presentation/pages` cho luồng V2/UI chung, `routing/`, `di/` modules.

# 6) Vấn đề kỹ thuật / rủi ro
- Config token/URL chỉ lưu RAM, mất sau restart → phải OTA lại.
- Retry WebSocket mỗi 2s không backoff, có thể spam server khi lỗi cấu hình.
- OTA upgrade không có validation chữ ký/kích thước; upgrade UI chưa gọi.
- Transport MQTT/UDP chưa dùng, chưa test; lựa chọn transport bị bỏ qua.
- Quyền bắt buộc quá nhiều, thiếu UX cho permanently denied/redirect settings.
- Audio pipeline thiếu AEC/NS/VAD/jitter buffer; không kiểm soát drift/samplerate mismatch.
- Logging/error message còn chung chung; thiếu heartbeat/close handling.
- UI Chat tối giản: không mic toggle/VU meter; dispose không stop listening rõ ràng.
- Base API `https://api.example.com` placeholder → auth thật không hoạt động.
- Test coverage thấp/chưa xác định pass; có test nhưng chưa chạy.

# 7) Plan phát triển tiếp (Roadmap)
## Phase 1 (1-3 ngày)
- Persist WebSocket/MQTT/token vào secure storage; hydrate ChatConfigProvider.
- Giảm quyền bắt buộc (chỉ mic + wifi), thêm xử lý permanently denied mở settings.
- Thêm logging cấu trúc cho connect/hello/listen/audio sizes; backoff retry đơn giản.

## Phase 2 (1-2 tuần)
- Hoàn thiện V2 flow: permission sheet + OTA fetch + trạng thái kết nối rõ, CTA kết nối chat; mic toggle/speaking indicator/VU meter; stop listening on dispose.
- Bật chọn transport MQTT/UDP theo settings/OTA; test happy-path + timeout.
- Bảo vệ OTA upgrade: validate size/hash, UI prompt, tắt nếu thiếu metadata.
- Viết/ sửa test: ChatConfigProvider, SessionCoordinator, OTA edge cases, permissions.

## Phase 3 (2-4 tuần)
- Audio robustness: jitter buffer/FEC, optional 20ms frames, VAD để giảm upload.
- Heartbeat/keepalive + exponential backoff cho reconnect; thống kê lỗi.
- UI/UX polish: activation flow, chat history/logging view, text-only mode, grouping V2 screens vào module riêng.
- Observability: structured logs exportable, minimal telemetry hooks.

# 8) Ưu tiên thực hiện (Priority)
- P0: Persist config/token; fix retry/backoff; quyền mic flow ổn định; logging cơ bản; chọn transport đúng config.
- P1: V2 flow hoàn chỉnh + mic controls; OTA validation; tests tối thiểu (form/chat/ota); handle permanently denied permissions.
- P2: Audio tối ưu (AEC/VAD/jitter); UX polish + module hóa V2; telemetry/metrics; text-only/chat UX nâng cao.

# 9) Gợi ý checklist trước khi release
- Build release cho các platform mục tiêu (Android/Windows/Web nếu cần).
- Fix crash/blocker sau khi bật quyền/OTA/transport thực tế.
- Test flow chính: permissions → form/OTA → activation → chat (WebSocket) trên thiết bị thật.
- Verify API/backend: URL/token từ OTA hợp lệ, baseUrl auth không còn placeholder.
- Bật logging/observability, kiểm tra reconnect/heartbeat hoạt động.

# Changelog (2026-01-31)
- Routing mặc định chuyển sang V2: `/home` và `/permissions` render V2 khi `AppConfig.useNewFlow=true`; V1 vẫn còn nếu flag tắt.
- Gộp đường dẫn V2 về routes chuẩn, bỏ `Routes.v2Home` và `Routes.v2Permissions`.
- Di chuyển V2 pages vào `lib/presentation/pages/v2/` để tách nhóm UI V2.
