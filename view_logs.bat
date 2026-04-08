@echo off
echo ========================================
echo   VoiceBot Log Viewer (Flutter Only)
echo ========================================
echo.
echo Filtering: Flutter logs only
echo To stop: Ctrl+C
echo.
adb logcat -s "flutter:I" "I/flutter:*"
