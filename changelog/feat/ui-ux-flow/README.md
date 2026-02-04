# Changelog - feat/ui-ux-flow

## 2026-02-04
- Added connect-greeting persistence + settings field, with short wake-word coercion for detect mode.
- Added Xiaozhi text service + greeting usecase to isolate payload/session handling and log send_text payloads.
- Added text send mode wiring + new cubits (carousel/text send/greeting) and DI/app hydration.
- Expanded home settings sheet with collapsible sections and detailed carousel controls (height/autoplay/interval/speed/viewport/enlarge).
- Rebuilt home UI widgets: header/content/footer split, added draggable camera overlay, and improved bottom carousel with full-screen preview.
- Enhanced settings sheet with tabs for Wi-Fi/audio/camera/theme/text scale plus listening mode selection and persisted UI settings.
- Added listening-mode plumbing through session coordinator and chat repository, plus manual-send button beside connect.
- Improved audio visual with idle animation when disconnected and refined transcript rendering/perf.
- Added carousel_slider dependency and synced text/icon scaling across the home UI.
- Added selectable theme palettes (neutral/green/lime) and persisted palette selection across launches.
- Reworked theme building to derive colors from palette specs and wire palette state through the app.
- Expanded settings sheet with palette tabs, text scale controls, and improved dismissal/blur handling.
- Adjusted emotion picker to a fixed 5/3-item layout so the selected item stays centered when text scale changes.
- Removed unused presentation widgets and legacy OTA/logger wrappers no longer referenced in the UI flow.

## 2026-02-02
- Simplified transcript rendering to static text and tightened emotion picker to 5 equal-width items without edge fades.
- Synced system status updates: battery level refreshes on state changes/clock tick and volume slider follows hardware volume stream.
- Added author footer link and locked footer button widths to avoid layout shifts when toggling theme.
- Added url_launcher wiring (pubspec + registrants) and cleaned test fakes/lints touched by the UI refresh.
- Rebuilt the primary home UI flow and consolidated v2 screens into `home_page`, removing legacy v2 pages, activation, and auth surfaces.
- Added a new chat session state manager (Cubit + session/state models) with speaking/level tracking and updated chat config/response handling.
- Introduced an MQTT transport client and refined WebSocket/MQTT protocol + session coordination for voice sessions.
- Added settings storage abstractions (secure/in-memory) and expanded settings repository, DI, config, theme, and logging wiring.
- Updated form/OTA/permission tests and added chat/home test scaffolding.
- Added theme mode toggle wiring (ThemeModeCubit + app theme mode control) and a footer toggle button.
- Standardized button sizing tokens and applied consistent heights/widths across footer, chat input, form, and permissions.
- Refined emotion UI (6-item picker sizing, edge fades) and refreshed pastel emotion tones including neutral.

## 2026-01-31
- Added v2 home UI with status header, pastel content, animated audio wave, and footer actions.
- Built v2 permissions sheet/page and routing updates for the new flow.
- Added Wi-Fi scan/connect popover+sheet, status updates, and settings shortcuts.
- Integrated XiaoZhi connect from the footer (OTA check, activation display, transcript surface).
- Updated platform wiring and plugins (audio route, wifi, volume, battery, carrier), minSdk 29, and registrants.
- Added third_party overrides for carrier_info and record_android plus lint/analysis tweaks.
