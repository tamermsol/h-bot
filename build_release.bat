@echo off
echo ========================================
echo Building Release APK for HBOT
echo ========================================
echo.

echo Step 1: Cleaning previous builds...
call flutter clean
echo.

echo Step 2: Getting dependencies...
call flutter pub get
echo.

echo Step 3: Building release APK...
call flutter build apk --release
echo.

echo ========================================
echo Build Complete!
echo ========================================
echo.
echo Your APK is located at:
echo build\app\outputs\flutter-apk\app-release.apk
echo.
echo You can install it on your Android device.
echo.
pause
