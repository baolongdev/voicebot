# Changelog - feat/ui-ux-flow

## 2026-02-04
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
