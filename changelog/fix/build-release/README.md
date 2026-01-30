# Changelog - fix/build-release

## 2026-01-30
- Added voice session module (transport/audio/session coordinator) to decouple protocol and audio by platform.
- Refactored chat controller/repository to use the session coordinator and transport client.
- Improved Windows audio playback path (stream fallback + chunked WAV) and removed forced 48k playback.
- Added speaking-aware STT filtering and listen restart delay to reduce echo/self-transcription.
- Updated plugin registrants and pubspec to reflect new voice module and platform plugins.

## 2026-01-29
- Added path overrides for flutter_sound and opus_flutter_windows to use vendored plugins.
- Vendored opus_flutter_windows with a Windows stub plugin to satisfy CMake build.
- Added a flutter_sound podspec alias for macOS plugin resolution.


