# Troubleshooting: "Error detecting network"

## Quick Fix Steps

### Step 1: Rebuild the App
**The code changes are in place, but you MUST rebuild the app for them to take effect.**

```bash
# Run this batch file (Windows):
rebuild_and_test.bat

# Or manually:
flutter clean
flutter pub get
flutter build apk --debug
flutter install
```

**Why**: The app on your device is still running the old code. You need to rebuild and reinstall.

---

### Step 2: Check Device Status
```bash
# Run this batch file:
check_device_status.bat

# Or manually check:
adb devices                                    # Should show your device
adb shell getprop ro.build.version.sdk        # Should be ≥29 for Android 10+
adb shell settings get secure location_mode   # Should be 3 (ON)
```

---

### Step 3: Grant Permissions
1. Open the app
2. When prompted, grant **Location** or **Nearby Wi-Fi Devices** permission
3. Ensure **Location Services** are ON in system settings

---

### Step 4: Monitor Logs
```bash
# Clear old logs
adb logcat -c

# Watch for SSID detection
adb logcat -s EnhancedWiFi:D flutter:I
```

**Expected output when working**:
```
D/EnhancedWiFi: Current Wi-Fi: SSID=MyHomeWiFi, 2.4GHz=true, IP=192.168.1.100
I/flutter: [DevicePairing] Current SSID: MyHomeWiFi
```

**If still failing**:
```
D/EnhancedWiFi: No active network
D/EnhancedWiFi: Active network is not Wi-Fi
D/EnhancedWiFi: SSID is unknown or empty: <unknown ssid>
E/EnhancedWiFi: Permission denied reading Wi-Fi info
```

---

## Common Issues & Solutions

### Issue 1: "Error detecting network" after rebuild

**Possible Causes**:
1. Location Services are OFF
2. Permission not granted
3. Not connected to Wi-Fi (on mobile data)
4. Enterprise/hidden SSID network

**Solutions**:

#### Check Location Services
```bash
adb shell settings get secure location_mode
```
- If returns `0`: Location is OFF
- If returns `3`: Location is ON

**Turn on Location**:
```bash
adb shell settings put secure location_mode 3
```
Or manually: Settings → Location → ON

#### Check Permissions
```bash
adb shell dumpsys package com.example.hbot | findstr "permission"
```

Look for:
- `android.permission.ACCESS_FINE_LOCATION: granted=true`
- `android.permission.NEARBY_WIFI_DEVICES: granted=true` (Android 13+)

**Grant permissions manually**:
Settings → Apps → Your App → Permissions → Location → Allow

#### Check Wi-Fi Connection
```bash
adb shell dumpsys wifi | findstr "mWifiInfo"
```

Should show something like:
```
mWifiInfo SSID: "MyHomeWiFi", BSSID: xx:xx:xx:xx:xx:xx
```

If shows `<unknown ssid>`, Location is likely OFF.

---

### Issue 2: Logcat shows "No active network"

**Cause**: Phone is not connected to Wi-Fi

**Solution**: Connect to a Wi-Fi network

---

### Issue 3: Logcat shows "Active network is not Wi-Fi"

**Cause**: Phone is on mobile data, not Wi-Fi

**Solution**: 
1. Turn off mobile data temporarily
2. Connect to Wi-Fi
3. Retry

---

### Issue 4: Logcat shows "Permission denied reading Wi-Fi info"

**Cause**: Location permission not granted

**Solution**:
1. Uninstall app: `adb uninstall com.example.hbot`
2. Reinstall: `flutter install`
3. Grant permission when prompted

---

### Issue 5: Logcat shows "SSID is unknown or empty: <unknown ssid>"

**Cause**: Location Services are OFF

**Solution**:
```bash
# Turn on Location
adb shell settings put secure location_mode 3

# Restart app
adb shell am force-stop com.example.hbot
adb shell am start -n com.example.hbot/.MainActivity
```

---

### Issue 6: App crashes when opening "Add Device"

**Cause**: Missing method in native code

**Solution**:
1. Verify `EnhancedWiFiPlugin.kt` has `getCurrentWifi()` method
2. Rebuild: `flutter clean && flutter build apk --debug`
3. Reinstall: `flutter install`

---

## Verification Checklist

Before testing, verify:

- [ ] Code changes are in `EnhancedWiFiPlugin.kt`:
  - [ ] `getCurrentWifi()` method exists
  - [ ] `isLocationEnabled()` method exists
  - [ ] Methods registered in `onMethodCall()`

- [ ] Code changes are in `enhanced_wifi_service.dart`:
  - [ ] `WifiInfo` class exists
  - [ ] `getCurrentWifiInfo()` method exists
  - [ ] `getCurrentSSID()` calls `getCurrentWifiInfo()` on Android

- [ ] App has been rebuilt:
  - [ ] `flutter clean` executed
  - [ ] `flutter pub get` executed
  - [ ] `flutter build apk --debug` executed
  - [ ] `flutter install` executed

- [ ] Device is ready:
  - [ ] Android 10+ (API 29+)
  - [ ] Location Services ON
  - [ ] Permissions granted
  - [ ] Connected to Wi-Fi

---

## Step-by-Step Test

### 1. Rebuild App
```bash
flutter clean
flutter pub get
flutter build apk --debug
flutter install
```

### 2. Start Logcat
```bash
adb logcat -c
adb logcat -s EnhancedWiFi:D flutter:I
```

### 3. Open App
- Launch app on device
- Navigate to "Add Device" screen

### 4. Check Logcat
**Expected (Success)**:
```
D/EnhancedWiFi: Current Wi-Fi: SSID=MyHomeWiFi, 2.4GHz=true, IP=192.168.1.100
I/flutter: [DevicePairing] Refreshing current SSID...
I/flutter: [DevicePairing] Current SSID: MyHomeWiFi
```

**If you see this (Failure)**:
```
D/EnhancedWiFi: No active network
```
→ Not connected to Wi-Fi

```
D/EnhancedWiFi: SSID is unknown or empty: <unknown ssid>
```
→ Location Services OFF

```
E/EnhancedWiFi: Permission denied reading Wi-Fi info
```
→ Permission not granted

### 5. Verify UI
- SSID field should show your Wi-Fi name (e.g., "MyHomeWiFi")
- Green "WiFi-2.4GHz" badge should appear (if on 2.4GHz)
- No "Error detecting network" message

---

## Manual Testing Commands

### Force Location ON
```bash
adb shell settings put secure location_mode 3
```

### Grant Location Permission
```bash
adb shell pm grant com.example.hbot android.permission.ACCESS_FINE_LOCATION
```

### Grant Nearby Wi-Fi Permission (Android 13+)
```bash
adb shell pm grant com.example.hbot android.permission.NEARBY_WIFI_DEVICES
```

### Restart App
```bash
adb shell am force-stop com.example.hbot
adb shell am start -n com.example.hbot/.MainActivity
```

### Check Current SSID (System)
```bash
adb shell dumpsys wifi | findstr "SSID"
```

---

## If Still Not Working

### 1. Verify Native Code Compilation
Check that Kotlin code compiled correctly:
```bash
# Look for EnhancedWiFiPlugin in APK
unzip -l build/app/outputs/flutter-apk/app-debug.apk | findstr EnhancedWiFiPlugin
```

Should show:
```
com/example/hbot/EnhancedWiFiPlugin.class
```

### 2. Check Method Channel Registration
Add debug log to verify channel is registered:

In `EnhancedWiFiPlugin.kt`, add to `onAttachedToEngine`:
```kotlin
Log.d("EnhancedWiFi", "Plugin attached, channel registered")
```

Rebuild and check logcat for this message.

### 3. Test Method Call Directly
Add debug log to `getCurrentWifi()`:
```kotlin
@SuppressLint("MissingPermission")
private fun getCurrentWifi(result: Result) {
    Log.d("EnhancedWiFi", "getCurrentWifi() called")  // Add this
    try {
        // ... rest of code
```

Rebuild and check if this log appears when opening "Add Device".

---

## Last Resort: Clean Reinstall

```bash
# 1. Uninstall app
adb uninstall com.example.hbot

# 2. Clean Flutter
flutter clean

# 3. Delete build folder
rmdir /s /q build

# 4. Get dependencies
flutter pub get

# 5. Build fresh
flutter build apk --debug

# 6. Install
flutter install

# 7. Grant permissions
adb shell pm grant com.example.hbot android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.hbot android.permission.NEARBY_WIFI_DEVICES

# 8. Turn on Location
adb shell settings put secure location_mode 3

# 9. Launch app
adb shell am start -n com.example.hbot/.MainActivity
```

---

## Contact Info

If issue persists after all steps:

1. Run `check_device_status.bat`
2. Capture logcat output: `adb logcat > logcat.txt`
3. Take screenshot of "Add Device" screen
4. Note:
   - Android version
   - Device model
   - Location Services status
   - Permissions granted

---

**Most Common Fix**: Just rebuild the app! The code is correct, but the old APK is still installed on your device.
