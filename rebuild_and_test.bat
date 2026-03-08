@echo off
echo ========================================
echo Rebuilding App with SSID Detection and Provisioning Fixes
echo ========================================
echo.
echo CRITICAL FIXES INCLUDED:
echo 1. Multi-method SSID detection for Android 13/14 (3 fallback methods)
echo 2. Enhanced SSID refresh with permission checks and logging
echo 3. Enhanced reconnection logging to diagnose issues
echo 4. POST to /wi with proper form encoding (handles special chars)
echo 5. Automatic reconnection to user Wi-Fi (WifiNetworkSuggestion)
echo 6. Provisioning retry logic (3 attempts)
echo 7. Network settling delay (1 second after binding)
echo.

echo Step 1: Cleaning previous build...
call flutter clean
if errorlevel 1 (
    echo ERROR: Flutter clean failed
    pause
    exit /b 1
)
echo ✓ Clean complete
echo.

echo Step 2: Getting dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Flutter pub get failed
    pause
    exit /b 1
)
echo ✓ Dependencies downloaded
echo.

echo Step 3: Building debug APK...
call flutter build apk --debug
if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)
echo ✓ Build complete
echo.

echo Step 4: Connecting to device...
echo Please connect your Android device via USB
echo.
pause

echo Step 5: Installing on connected device...
call flutter install
if errorlevel 1 (
    echo.
    echo ERROR: Install failed
    echo.
    echo Troubleshooting:
    echo 1. Is device connected? Run: adb devices
    echo 2. Is USB debugging enabled?
    echo 3. Try: adb install -r build\app\outputs\flutter-apk\app-debug.apk
    echo.
    pause
    exit /b 1
)
echo ✓ App installed
echo.

echo ========================================
echo Build and Install Complete!
echo ========================================
echo.
echo WHAT TO TEST:
echo.
echo 1. Open the app on your device
echo 2. Navigate to "Add Device" screen
echo 3. Grant BOTH permissions when prompted:
echo    - Nearby Wi-Fi devices
echo    - Location
echo 4. Turn ON Location Services if prompted
echo 5. Check if SSID auto-detects:
echo    - If YES: Great! Enter password and proceed
echo    - If NO: Manually enter SSID and password
echo 6. Tap "Next" to proceed to device discovery
echo 7. Scan for devices and select one
echo 8. Watch the provisioning process
echo 9. CRITICAL: Watch for reconnection logs
echo.
echo Expected Results:
echo ✓ SSID auto-detected OR manual entry works
echo ✓ Device receives Wi-Fi credentials (POST to /wi)
echo ✓ Phone AUTOMATICALLY reconnects to your Wi-Fi
echo ✓ Device appears in your account
echo ✓ No more "stuck at verifying internet connectivity"
echo.
echo IMPORTANT - Monitor Logs:
echo Open a NEW terminal and run:
echo   adb logcat -c
echo   adb logcat -s EnhancedWiFi:D flutter:I
echo.
echo Watch for these key logs:
echo 1. SSID Detection:
echo    "✅ Current SSID detected: YourWiFiName"
echo    OR "⚠️ SSID not available - please enter manually"
echo.
echo 2. Provisioning:
echo    "🔧 Provisioning WiFi to SSID: YourWiFiName"
echo    "✅ WiFi credentials sent successfully on attempt 1"
echo.
echo 3. Reconnection (CRITICAL):
echo    "Current credentials - SSID: YourWiFiName, Password: ***"
echo    "🔄 Reconnecting to user Wi-Fi: YourWiFiName"
echo    "✅ Successfully reconnected to YourWiFiName"
echo.
echo If you see "SSID: null" in the reconnection logs, that's the bug!
echo.
echo Documentation:
echo - FIX_SUMMARY_SSID_AND_PROVISIONING.md - Complete fix summary
echo - TROUBLESHOOTING_STUCK_AT_VERIFYING.md - Troubleshooting guide
echo - PROVISIONING_COMPLETE_FIX.md - Provisioning fixes
echo - ANDROID_13_14_COMPLETE_FIX.md - SSID detection fix
echo.
pause

