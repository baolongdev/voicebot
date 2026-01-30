# AGENT.md

### 1️⃣ Project Identity & Purpose

- XiaoZhi voice assistant **client** built with Flutter, targeting mobile/desktop (Android/Windows WebSocket stack) with IoT-style OTA activation and device identity payloads.
- Solves end-to-end voice session: microphone → Opus encode → transport (WebSocket today, MQTT/UDP planned) → LLM/STT/TTS server → audio playback.
- Designed for XiaoZhi backend expecting device identity (MAC/UUID) and OTA-provisioned endpoints/tokens; user role is to configure server, obtain activation, and talk hands-free.
- Audio-first: UI is minimal chat shell; pipeline streams PCM/Opus both ways, treats text chat as supplemental.

### 2️⃣ High-Level Architecture Overview

- Pattern: Clean Architecture with DI (`get_it`) and feature modules; domain/application independent of transport/UI; infrastructure bridges protocols/audio/permissions/OTA.
- Dependency direction: `presentation → application → domain → core`; infrastructure implements domain contracts; capabilities provide low-level I/O.
- Layer diagram (text):
  - **core**: configs (`AppConfig`), errors/result, audio constants, logging, OTA models.
  - **capabilities**: protocol clients (WebSocket, MQTT+UDP), audio recorder/player, protocol abstractions.
  - **features**: auth, chat, form (server setup), home, activation; each has domain/entities/usecases + infrastructure + presentation widgets.
  - **infrastructure**: permission service impl, form/settings persistence (in-memory), chat repos.
  - **presentation**: ForUI-based pages (home/form/auth/chat/activation) plus widgets.
  - **routing**: go_router with guards for auth/permissions; splash/auth/home/form/activation/chat routes.
  - **system**: OTA implementation, permissions cubit/view, platform wrappers.
- Clean Architecture chosen to isolate protocols/audio from UI, enable swapping WebSocket ↔ MQTT/UDP and plugging platform services (OTA, permissions) without touching widgets.

### 2.1 Branch Naming Convention

Danh sách type:

- feat/ thêm tính năng
- fix/ sửa bug
- chore/ dọn dẹp, đổi config, tooling
- refactor/ thay đổi cấu trúc, không đổi hành vi
- perf/ tối ưu hiệu năng
- test/ thêm/sửa test
- docs/ tài liệu
- ci/ pipeline CI/CD
- build/ build system, build config
- hotfix/ vá gấp trên production

### 2.2 Skill Usage Examples

- Changelog theo nhánh:
  - "Ghi changelog cho branch hiện tại giúp tôi."
  - "Tóm tắt thay đổi mới nhất và ghi vào changelog/<branch>/README.md."
  - "Tạo ghi chú lịch sử cho nhánh `feat/chat-audio`."
- Git/GitHub:
  - "Stage các file vừa đổi và commit với message `fix: update build workflow`."
  - "Commit và push lên GitHub cho tôi."
  - "Tự viết commit message theo branch hiện tại và push giúp tôi."
  - "Xóa nhánh local và remote `feat/old-experiment`."
- Mix:
  - Tóm tắt thay đổi mới nhất và ghi vào changelog/<branch>/README.md. VÀ Tự viết commit message theo branch hiện tại và push giúp tôi.

### 3️⃣ Feature-by-Feature Status (What Is DONE)

#### 3.1 Permissions

- Behavior: `PermissionCubit` checks microphone at app start (if `AppConfig.permissionsEnabled` true); request path exists but UI (`PermissionRequestView`) not analyzed here; readiness gate in router redirects to `/permissions` until granted.
- Known issues: Only microphone is required; Bluetooth/Wi-Fi/file enums exist but are auto-granted in impl. No handling of permanently denied flows beyond status; no rationale UI.
- Risks: Permissions disabled via config by default? (`permissionsEnabled` true but auth disabled); recording starts without explicit runtime prompt if already granted.

#### 3.2 OTA & Activation

- Flow: Server form submit (XiaoZhi) calls `Ota.checkVersion(qtaUrl)` with generated/stored MAC+UUID; parses MQTT/WebSocket/activation/firmware info into `OtaResult`.
- Data retrieved: MQTT config, optional WebSocket URL/token override, activation code/message, firmware URL/version, server time, device info echoed.
- Persistence: Stored only in memory (`SettingsRepositoryImpl` fields); device identity persisted in secure storage (mac/uuid). Firmware download/upgrade implemented but not triggered in UI.
- Not auto-triggered: Upgrade is manual (`startUpgrade` unused), activation only displayed on Activation page; no background OTA.

#### 3.3 Chat / Voice Session

- Purpose: Maintain voice session to backend; show transcripts and allow manual text send.
- Status: `ChatController` initializes streams, connects via `ChatConfigProvider` → WebSocket, starts audio pipeline, sends auto listen start, buffers messages.
- State machine: Tracks messages, sending flag, speaking flag; retries connect on failure every 2s; waits for TTS stop before re-listen.
- Protocol interaction: Sends hello then start listening; sends text payload (`type:text`) with session_id; auto-encodes PCM to Opus and streams.
- UI behavior: Simple list + text input; shows connection error string; no VU meters or mic toggle; no visual speaking indicator.
- Missing: `stopListening` use case wired but repository lacks implementation (compile error), no explicit close on page pop beyond dispose.

#### 3.4 Audio Pipeline

- Recorder: `FlutterSoundRecorder` 16kHz mono, 60ms frames (1920 samples -> 3840 bytes) chunked; no AEC/NS.
- Encoder: `opus_dart` streaming encoder (`FrameTime.ms60`, mono) feeding protocol `sendAudio`.
- Player: `OpusStreamPlayer` decodes incoming Opus frames, buffers min 3 frames, plays via native AudioTrack on Android or FlutterSound elsewhere; waits for quiet window before resuming listen.
- Timing assumptions: Frame duration fixed 60ms; playback sample rate may switch to server value if provided; no jitter/PLC; no backpressure on send.

#### 3.5 WebSocket Protocol

- Handshake: Connect with headers Authorization Bearer <token>, Protocol-Version:1, Device-Id (mac lower), Client-Id (uuid); immediately send hello `{type:hello, version:1, transport:websocket, audio_params{format:opus,sample_rate:16000,channels:1,frame_duration:60}}`.
- Hello response: Expects `transport:websocket`, optional `audio_params.sample_rate`, `session_id`; stored and unblocks connection future.
- Listen/start: `ChatRepository.startListening` sends `{type:listen,state:start,mode:auto}` (auto-stop). Stop not used (and repository lacks API).
- Audio streaming: Binary frames sent raw via WebSocket; incoming binary pushed to Opus decoder.
- Close behavior: `disconnect` closes socket; onDone logs code/reason; no heartbeat/ping.

#### 3.6 MQTT + UDP (if present)

- Control vs data: MQTT carries control JSON (hello/goodbye/listen, etc.); UDP carries Opus audio with AES-CTR envelope (nonce+seq in first 16 bytes).
- Encryption: AES-CTR with key/nonce from server hello; sequence tracked to drop old packets.
- Readiness: Implemented but not wired into ChatRepository or config selector; Settings holds transport type but ChatRepository always uses WebSocket. No tests.

### 4️⃣ Runtime Flow (End-to-End)

1. App start (`main`): init Opus libs; fullscreen mode; `configureDependencies` registers DI.
2. Permission check: `PermissionCubit.checkRequiredPermissions` auto-runs; router blocks to `/permissions` until ready.
3. Server configuration: User goes Home → Form; selects XiaoZhi/SelfHost and submits.
4. OTA check: Form submit triggers `Ota.checkVersion(qtaUrl)`; device identity persisted; response stored in memory + emitted.
5. Activation: If OTA includes activation, UI shows code/message on Activation page; Continue navigates to chat.
6. Chat initialization: `ChatController.initialize` attaches streams and loads config (WebSocket URL/token/deviceInfo from OTA/Settings).
7. Protocol connect: WebSocket connect with headers; send hello; wait for server hello; set session_id, sample_rate.
8. Audio streaming: Start recorder → Opus encode → `sendAudio`; send listen start; incoming audio decoded to PCM and played after buffer fill.
9. Server response handling: Incoming JSON routed: `tts` sets speaking state (start/stop, sentence_start emits bot text), `stt` emits user transcript, other text forwarded as bot message; errors push to error stream.
10. Session end/failure: `disconnect` on dispose; network errors surface as failure; retry timer reconnects every 2s without backoff.

### 5️⃣ Technical Debt & Known Gaps (CRITICAL)

- Missing API: `ChatRepository` lacks `stopListening`, causing compile/LSP error (`StopListeningUseCase` unusable).
- Transport selection unused: MQTT/UDP never chosen even if OTA provides MQTT config/transport flag; Settings not persisted beyond memory.
- Token persistence: WebSocket token/URL stored in memory only; lost after app restart; no secure storage for session tokens.
- Error handling: Many network errors mapped to generic strings; no granular codes; retries unbounded every 2s (risk of hammering).
- Audio robustness: No AEC/NS/VAD; no buffering control for outgoing Opus; decoder ignores forward error correction.
- Permission gaps: Auto-grants Wi-Fi/audio types; no handling for permanently denied mic or settings redirection.
- OTA upgrade: Download/flash flow implemented but never invoked; firmware URL used without signature/size checks; hardcoded ELF hash.
- Hardcoded values: API base URL `https://api.example.com`; default XiaoZhi endpoints/tokens? (token comes from OTA; transport default MQTT). User agent, accept-language, board info static in OTA payload.
- Logging only stdout; no structured logs/metrics; Native AudioTrack channel assumed but not implemented on platforms other than Android.
- Tests failing: Analyzer reports missing `stopListening`; form_repository_impl_test references `websocket` required arg (build failure).

### 6️⃣ Risks & Failure Modes

- Runtime crash/compile stop due to missing `stopListening` method in repository interface implementation.
- Connection loops: If config missing token/URL, controller schedules endless retries with same error.
- Audio drift: Playback buffer thresholds may underflow/overflow on high jitter; no sample-rate conversion if server sends different frame params beyond sample_rate.
- Security: MQTT/UDP AES keys handled in memory only; no TLS verification settings; OTA uses http client without pinning; firmware download lacks integrity check.
- Permissions: If mic permanently denied, router may loop to permissions without actionable UX; recording attempts may fail silently.
- Debuggability: Network errors surfaced as generic strings (“Server not found/timeout”); no per-message logging hooks.

### 7️⃣ Checkpoint Assessment (Current State)

- Maturity: Prototype/early-alpha; UI minimal; features ported from Android but partially wired.
- Safe environments: Dev/lab with controlled XiaoZhi backend and trusted network; not production-ready for end users.
- Validated: OTA checkVersion covered by tests; WebSocket happy-path connect/send implemented; basic recorder/encoder pipeline stands.
- Unvalidated: MQTT/UDP path, firmware upgrade, activation persistence, auth (disabled), permissions UX, resilience under poor networks.
- Assumptions: Server speaks XiaoZhi protocol (hello/listen/tts/stt), sends Opus frames matching 60ms/16k mono; token delivered via OTA.

### 8️⃣ Forward Plan (VERY DETAILED)

#### Phase 1: Observability & Logging

- Goal: Make runtime issues diagnosable.
- Why: Current generic errors obscure root causes.
- Tasks: Add structured logging hooks around protocol events (connect/hello/listen/audio sizes), audio stats (underruns), permission outcomes; persist recent logs for support.
- Outcome: Reproducible traces for connect/audio bugs.
- Dependencies: None; safe to start.

#### Phase 2: Protocol Correctness Validation

- Goal: Ensure WebSocket + MQTT/UDP align with server contract.
- Why: Prevent silent mismatches causing no audio or stuck sessions.
- Tasks: Implement `stopListening` in repo/protocol; confirm text payload schema; add heartbeat/ping or reconnect rules; honor OTA transport selection and switch between WebSocket/MQTT.
- Outcome: Successful bidirectional audio across chosen transport; fewer protocol errors.
- Dependencies: Logging from Phase 1.

#### Phase 3: Permission & Lifecycle Hardening

- Goal: Robust mic gating and lifecycle cleanup.
- Why: Prevent loops and background recording.
- Tasks: Add permanent-deny UX with settings deep link; pause/stop recorder on page dispose or app pause; gate chat init until permissions granted; expand required permissions per platform.
- Outcome: Predictable mic behavior and routing.
- Dependencies: None; can parallel Phase 2.

#### Phase 4: Audio Stability & Timing

- Goal: Reduce glitches and improve voice quality.
- Why: 60ms frames and no jitter buffer risk dropouts.
- Tasks: Add jitter buffer/FEC support; evaluate 20ms frames; add VAD to throttle send; handle server sample rate mismatch via resampling; monitor latency/drift.
- Outcome: Stable streaming under variable networks.
- Dependencies: Protocol correctness.

#### Phase 5: Production Readiness

- Goal: Persist config securely and handle upgrades safely.
- Why: Current state loses tokens and skips firmware safety.
- Tasks: Persist WebSocket/MQTT settings in secure storage; add OTA signature/size validation and user prompt; add graceful backoff for retries; UI states for errors/speaking indicators.
- Outcome: Durable sessions across restarts; safer OTA.
- Dependencies: Phases 1–3.

#### Phase 6: Optional Enhancements (UI / text input / testing)

- Goal: Improve usability and coverage.
- Why: Current UI is developer-oriented.
- Tasks: Add mic toggle + visualizer; show TTS/speaking status; allow text-only mode; expand widget/unit tests (chat controller, protocol parsing, permissions); implement auth if needed.
- Outcome: Better UX and test safety net.
- Dependencies: After core stability.

### 9️⃣ Non-Goals (IMPORTANT)

- Not building server-side LLM/STT/TTS; client-only.
- Not providing offline/embedded ASR/TTS.
- Not implementing full IoT device firmware flashing beyond current simulated OTA flow.
- Not delivering analytics/telemetry backend in this phase.

### 🔟 Final Summary (One-Page Executive View)

- What exists: Flutter Clean Architecture prototype for XiaoZhi voice client with OTA-driven config, WebSocket audio chat, Opus recorder/player, permission gate, DI wiring, and OTA unit tests.
- Blocks to success: Missing `stopListening` impl, unused MQTT/UDP path, non-persistent config/tokens, limited error handling, no upgrade trigger/validation, permission UX gaps.
- Next milestone: Stabilize protocol + audio (Phases 1–4), persist OTA-derived settings, and harden permissions/lifecycle to reach beta-quality voice sessions.
