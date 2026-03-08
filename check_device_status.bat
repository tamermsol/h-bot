@echo off
echo ========================================
echo Device Status Check
echo ========================================
echo.

echo Checking connected devices...
adb devices
echo.

echo Checking Android version...
adb shell getprop ro.build.version.sdk
echo.

echo Checking Location Services status...
adb shell settings get secure location_mode
echo (0 = OFF, 3 = ON)
echo.

echo Checking current Wi-Fi connection...
adb shell dumpsys wifi | findstr "mWifiInfo"
echo.

echo Checking app permissions...
adb shell dumpsys package com.example.hbot | findstr "permission"
echo.

echo ========================================
echo To start monitoring logs, run:
echo   adb logcat -c
echo   adb logcat -s EnhancedWiFi:D flutter:I
echo ========================================
pause

