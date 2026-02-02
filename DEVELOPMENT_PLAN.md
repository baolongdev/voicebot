# Goal
Ổn định client Flutter trợ lý giọng nói XiaoZhi: cấu hình OTA bền vững, kết nối/stream audio tin cậy, UI V2 usable, và sẵn sàng thử nghiệm nội bộ trên Android/Windows.

# Current Status (đã làm được gì)
- WebSocket chat hoạt động: hello/listen, encode Opus, playback, retry 2s (`lib/features/chat/**`, `lib/capabilities/voice/**`).
- Form cấu hình + OTA fetch, parse WebSocket/MQTT/activation/firmware, lưu device identity secure storage (`lib/features/form/**`, `lib/system/ota/ota.dart`).
- Permission flow v1/v2 bằng Bloc, UI sheet v2 (`lib/system/permissions/**`, `lib/presentation/pages/v2_permissions_page.dart`).
- V2 Home dashboard thử nghiệm (pin/mạng/âm lượng/Wi‑Fi scan, CTA kết nối) (`lib/presentation/pages/v2_home_page.dart`).
- Auth module đầy đủ nhưng tắt qua config (`lib/features/auth/**`).

# Next Milestones
- Milestone 1 (tuần này): Persist cấu hình OTA, ổn định quyền mic, thêm logging + retry backoff cơ bản, luồng V2 kết nối tối thiểu.
- Milestone 2 (tuần sau): Hoàn thiện V2 (mic toggle/speaking indicator, stopListening dispose), bật chọn transport MQTT/UDP theo config, OTA upgrade guard (size/hash), bổ sung test tối thiểu.
- Milestone 3 (tháng này): Audio robustness (jitter buffer/VAD/FEC-lite), heartbeat + exponential backoff, telemetry/log export, UX polish (text-only mode, module hoá V2 UI).

# Task breakdown
- Persist WebSocket/MQTT/token sau OTA vào secure storage; hydrate ChatConfigProvider

- Giảm quyền bắt buộc, thêm xử lý permanently denied + mở settings

- Logging & retry backoff cho chat connect

- V2 Home: kết nối/OTA tối thiểu + CTA hành động rõ

- Mic toggle + speaking indicator + stopListening on dispose

- Chọn transport MQTT/UDP theo config và test happy-path

- OTA upgrade guard (size/hash) và tắt nếu thiếu metadata

- Test coverage tối thiểu cho form/permissions/chat config

- Audio robustness (jitter buffer/VAD/FEC-lite)

- Heartbeat + exponential backoff + telemetry hook

- Module hoá V2 UI và polish UX (text-only mode, activation polish)
