# Changelog - feat/ui-ux-flow

## 2026-02-02
- Rebuilt the primary home UI flow and consolidated v2 screens into `home_page`, removing legacy v2 pages, activation, and auth surfaces.
- Added a new chat session state manager (Cubit + session/state models) with speaking/level tracking and updated chat config/response handling.
- Introduced an MQTT transport client and refined WebSocket/MQTT protocol + session coordination for voice sessions.
- Added settings storage abstractions (secure/in-memory) and expanded settings repository, DI, config, theme, and logging wiring.
- Updated form/OTA/permission tests and added chat/home test scaffolding.

## 2026-01-31
- Added v2 home UI with status header, pastel content, animated audio wave, and footer actions.
- Built v2 permissions sheet/page and routing updates for the new flow.
- Added Wi-Fi scan/connect popover+sheet, status updates, and settings shortcuts.
- Integrated XiaoZhi connect from the footer (OTA check, activation display, transcript surface).
- Updated platform wiring and plugins (audio route, wifi, volume, battery, carrier), minSdk 29, and registrants.
- Added third_party overrides for carrier_info and record_android plus lint/analysis tweaks.
