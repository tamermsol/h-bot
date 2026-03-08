# Testing Guide for Android 10-14 Wi-Fi Fix

## Quick Test Steps

### 1. Build and Install
```bash
flutter clean
flutter pub get
flutter build apk --debug
# Or for release:
flutter build apk --release
```

Install on your Android 10-14 device.

### 2. Enable Developer Options & USB Debugging
1. Settings → About Phone → Tap "Build Number" 7 times
2. Settings → Developer Options → Enable "USB Debugging"
3. Connect phone to computer via USB

### 3. Monitor Logcat
Open a terminal and run:
```bash
adb logcat -s EnhancedWiFi:D Flutter:D
```

This will show only relevant logs from the Wi-Fi plugin and Flutter.

### 4. Test Provisioning Flow

#### Step 1: Launch App
- Open the app
- Grant all permissions when prompted (Location or Nearby Wi-Fi Devices)
- Ensure Location Services are ON

#### Step 2: Scan for Devices
- Tap "Add Device" or similar
- App should scan for Hbot-* networks
- **Expected Logcat**:
  ```
  D/EnhancedWiFi: Found X hbot networks: [Hbot-Shutter-BC8397-0919, ...]
  ```

#### Step 3: Connect to Device SoftAP
- Select a device from the list
- **What should happen**:
  - Android shows a minimal connection dialog (NOT "Open with" chooser)
  - Connection happens automatically
  
- **Expected Logcat**:
  ```
  D/EnhancedWiFi: Network available: [Network 123]
  D/EnhancedWiFi: Successfully bound to SoftAP network
  D/EnhancedWiFi: Connection successful, network is bound
  ```

- **❌ FAIL if you see**:
  - "Open with" chooser dialog
  - "Failed to bind to SoftAP network"
  - "Network unavailable"

#### Step 4: Fetch Device Info
- App should automatically fetch device info from `http://192.168.4.1`
- **Expected Logcat**:
  ```
  I/flutter: 🔍 Fetching device info from SoftAP...
  I/flutter: ✅ Device info fetched successfully
  ```

- **❌ FAIL if you see**:
  ```
  E/flutter: ❌ Failed to fetch device information: ClientException with SocketException: Connection failed (OS Error: Network is unreachable, errno = 101)
  ```

#### Step 5: Provision Wi-Fi
- Enter your home Wi-Fi SSID and password
- Tap "Provision" or "Connect"
- **Expected Logcat**:
  ```
  I/flutter: 🔧 Provisioning WiFi with URL: http://192.168.4.1/wi?s1=...
  I/flutter: ✅ WiFi provisioned successfully
  ```

#### Step 6: Disconnect from SoftAP
- App should automatically disconnect after provisioning
- **Expected Logcat**:
  ```
  D/EnhancedWiFi: Starting disconnection from hbot AP
  D/EnhancedWiFi: Process unbound from SoftAP network
  D/EnhancedWiFi: Network callback unregistered
  D/EnhancedWiFi: Disconnection completed successfully
  ```

#### Step 7: Verify Internet Reconnection
- Phone should automatically reconnect to mobile data or previous Wi-Fi
- Open a browser and verify internet works
- **Expected**: Internet should work normally

### 5. Verify Device Joined Home Network
- Wait 30-60 seconds for device to reboot
- Device should appear in your home network
- App should discover it via mDNS or MQTT

## Common Issues & Solutions

### Issue: "Open with" Chooser Still Appears
**Cause**: App is falling back to legacy method or Settings intent

**Solution**:
1. Check Android version: `adb shell getprop ro.build.version.sdk`
2. Should be ≥29 for modern API
3. Check Logcat for "Modern API requires Android 10+"

### Issue: errno=101 (Network Unreachable)
**Cause**: Process not bound to SoftAP network

**Solution**:
1. Check Logcat for "Successfully bound to SoftAP network"
2. If missing, check for "Failed to bind to SoftAP network"
3. Verify `CHANGE_NETWORK_STATE` permission in manifest
4. Rebuild app: `flutter clean && flutter build apk`

### Issue: "Network unavailable"
**Cause**: Can't connect to device SoftAP

**Solution**:
1. Verify device is in AP mode (LED blinking, etc.)
2. Check SSID is correct (case-sensitive)
3. Move phone closer to device
4. Manually connect to device SoftAP in Settings to verify it's broadcasting

### Issue: Permissions Denied
**Cause**: Missing location or nearby Wi-Fi devices permission

**Solution**:
1. Android 13+: Grant "Nearby Wi-Fi devices" permission
2. Android 10-12: Grant "Location" permission
3. Enable Location Services in Settings
4. Restart app after granting permissions

### Issue: Cleartext HTTP Blocked
**Cause**: Network security config not allowing 192.168.4.1

**Solution**:
1. Verify `network_security_config.xml` includes `192.168.4.1`
2. Rebuild app: `flutter clean && flutter build apk`
3. Check Logcat for "Cleartext HTTP traffic not permitted"

## Logcat Filtering Tips

### Show only Wi-Fi related logs:
```bash
adb logcat -s EnhancedWiFi:D
```

### Show only Flutter logs:
```bash
adb logcat -s flutter:I
```

### Show both:
```bash
adb logcat -s EnhancedWiFi:D flutter:I
```

### Show all logs (verbose):
```bash
adb logcat
```

### Clear logcat before test:
```bash
adb logcat -c
```

## Success Criteria

✅ **All of these must be true**:
1. No "Open with" chooser appears
2. Connection to SoftAP succeeds automatically
3. Logcat shows "Successfully bound to SoftAP network"
4. HTTP requests to 192.168.4.1 succeed (no errno=101)
5. Device info is fetched successfully
6. Wi-Fi provisioning completes
7. Phone reconnects to internet after provisioning
8. Device appears on home network after reboot

## Test Matrix

| Android Version | API Level | Expected Behavior |
|----------------|-----------|-------------------|
| Android 14 | 34 | Modern API, auto-connect |
| Android 13 | 33 | Modern API, auto-connect |
| Android 12L | 32 | Modern API, auto-connect |
| Android 12 | 31 | Modern API, auto-connect |
| Android 11 | 30 | Modern API, auto-connect |
| Android 10 | 29 | Modern API, auto-connect |
| Android 9 | 28 | Legacy fallback, manual |
| Android 8 | 26-27 | Legacy fallback, manual |

## Debugging Commands

### Check Android version:
```bash
adb shell getprop ro.build.version.sdk
```

### Check current Wi-Fi connection:
```bash
adb shell dumpsys wifi | grep "mWifiInfo"
```

### Check app permissions:
```bash
adb shell dumpsys package com.example.hbot | grep permission
```

### Force stop app:
```bash
adb shell am force-stop com.example.hbot
```

### Restart app:
```bash
adb shell am start -n com.example.hbot/.MainActivity
```

## Video Recording Test

To record a video of the test for debugging:
```bash
adb shell screenrecord /sdcard/test.mp4
# Run your test
# Press Ctrl+C to stop recording
adb pull /sdcard/test.mp4
```

## Report Template

If issues persist, provide this information:

```
**Device**: [e.g., Pixel 6, Samsung Galaxy S21]
**Android Version**: [e.g., Android 13]
**API Level**: [from `adb shell getprop ro.build.version.sdk`]

**Issue**: [Describe what's happening]

**Expected**: [What should happen]

**Logcat Output**:
```
[Paste relevant logcat output here]
```

**Steps to Reproduce**:
1. 
2. 
3. 

**Screenshots/Video**: [Attach if available]
```

## Next Steps After Successful Test

1. Test on multiple Android versions (10, 11, 12, 13, 14)
2. Test on different device manufacturers (Samsung, Pixel, Xiaomi, etc.)
3. Test with different Wi-Fi passwords (special characters, long passwords)
4. Test with weak SoftAP signal (move phone far from device)
5. Test with multiple devices in range
6. Test provisioning multiple devices in sequence

Good luck! 🚀
