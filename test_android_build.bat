@echo off
echo ========================================
echo Testing Android SDK 36 Build
echo ========================================
echo.
echo This script will test the Android SDK update and build the app.
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

echo Step 3: Building debug APK with Android SDK 36...
call flutter build apk --debug
if errorlevel 1 (
    echo.
    echo ❌ BUILD FAILED
    echo.
    echo Common issues:
    echo 1. Android SDK 36 not installed
    echo    - Open Android Studio
    echo    - Tools → SDK Manager
    echo    - Install "Android 15.0 (API 36)"
    echo.
    echo 2. Java 17 not installed
    echo    - Download from: https://adoptium.net/
    echo    - Install Java 17 (LTS)
    echo    - Set JAVA_HOME environment variable
    echo.
    pause
    exit /b 1
)
echo ✓ Build complete
echo.

echo ========================================
echo ✅ BUILD SUCCESSFUL!
echo ========================================
echo.
echo Android SDK 36 build completed successfully!
echo.
echo Next steps:
echo 1. Install the app: flutter install
echo 2. Test shutter device synchronization
echo 3. Monitor logs: adb logcat -s flutter:I
echo.
echo To test real-time sync:
echo - Open app and view a shutter device
echo - Manually move the shutter (physical button)
echo - Watch the app update within 30 seconds
echo.
pause

