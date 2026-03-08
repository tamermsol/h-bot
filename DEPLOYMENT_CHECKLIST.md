# Deployment Checklist: Android 10-14 Wi-Fi Fix

## Pre-Deployment Verification

### ✅ Code Changes
- [x] `EnhancedWiFiPlugin.kt` - Added `boundNetwork` property
- [x] `EnhancedWiFiPlugin.kt` - Added `removeCapability(NET_CAPABILITY_INTERNET)`
- [x] `EnhancedWiFiPlugin.kt` - Added `bindProcessToNetwork(network)` in `onAvailable()`
- [x] `EnhancedWiFiPlugin.kt` - Added `bindProcessToNetwork(null)` in `disconnectFromHbotAP()`
- [x] `EnhancedWiFiPlugin.kt` - Added `onLost()` callback for auto-unbind
- [x] `EnhancedWiFiPlugin.kt` - Added `isBound` method
- [x] `network_security_config.xml` - Added `192.168.4.1` domain
- [x] `AndroidManifest.xml` - Added Wi-Fi and location feature declarations

### ✅ Build Verification
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Run `flutter build apk --debug` (should succeed)
- [ ] No compilation errors
- [ ] No IDE warnings in modified files

### ✅ Documentation
- [x] `ANDROID_10_14_WIFI_FIX.md` - Technical explanation
- [x] `TESTING_GUIDE.md` - Testing instructions
- [x] `CHANGES_SUMMARY.md` - Change summary
- [x] `QUICK_REFERENCE.md` - Quick reference
- [x] `DEPLOYMENT_CHECKLIST.md` - This file

---

## Testing Phase

### Device Preparation
- [ ] Android 10 device available
- [ ] Android 11 device available (optional but recommended)
- [ ] Android 12 device available (optional but recommended)
- [ ] Android 13 device available (optional but recommended)
- [ ] Android 14 device available (optional but recommended)
- [ ] USB debugging enabled on all devices
- [ ] ADB installed on development machine

### Test Environment
- [ ] Device SoftAP is broadcasting (Hbot-* SSID visible)
- [ ] Device is in provisioning mode
- [ ] Home Wi-Fi credentials ready for testing
- [ ] Logcat monitoring set up: `adb logcat -s EnhancedWiFi:D flutter:I`

### Test Execution

#### Test 1: Scan for Devices
- [ ] Launch app
- [ ] Grant permissions when prompted
- [ ] Tap "Add Device" or scan button
- [ ] Verify devices appear in list
- [ ] **Expected**: List of Hbot-* devices
- [ ] **Logcat**: `Found X hbot networks: [...]`

#### Test 2: Connect to Device SoftAP
- [ ] Select a device from list
- [ ] **Expected**: No "Open with" chooser appears
- [ ] **Expected**: Connection happens automatically
- [ ] **Logcat**: 
  ```
  D/EnhancedWiFi: Network available: [Network XXX]
  D/EnhancedWiFi: Successfully bound to SoftAP network
  D/EnhancedWiFi: Connection successful, network is bound
  ```
- [ ] **FAIL if**: "Open with" chooser appears
- [ ] **FAIL if**: "Failed to bind to SoftAP network" in logcat

#### Test 3: Fetch Device Info
- [ ] App should automatically fetch device info
- [ ] **Expected**: Device info displayed (topic, channels, etc.)
- [ ] **Logcat**: `✅ Device info fetched successfully`
- [ ] **FAIL if**: `errno = 101` error
- [ ] **FAIL if**: "Network is unreachable" error

#### Test 4: Provision Wi-Fi
- [ ] Enter home Wi-Fi SSID and password
- [ ] Tap "Provision" or "Connect"
- [ ] **Expected**: Success message
- [ ] **Logcat**: `✅ WiFi provisioned successfully`
- [ ] **Expected**: Device reboots (may lose connection)

#### Test 5: Disconnect from SoftAP
- [ ] App should automatically disconnect
- [ ] **Expected**: Phone reconnects to internet
- [ ] **Logcat**:
  ```
  D/EnhancedWiFi: Starting disconnection from hbot AP
  D/EnhancedWiFi: Process unbound from SoftAP network
  D/EnhancedWiFi: Disconnection completed successfully
  ```
- [ ] Open browser and verify internet works

#### Test 6: Device Joins Home Network
- [ ] Wait 30-60 seconds for device to reboot
- [ ] Device should appear on home network
- [ ] App should discover device via mDNS/MQTT
- [ ] **Expected**: Device appears in app's device list
- [ ] **Expected**: Can control device

### Edge Case Testing

#### Test 7: Weak Signal
- [ ] Move phone far from device SoftAP
- [ ] Attempt provisioning
- [ ] **Expected**: Graceful timeout or retry

#### Test 8: Wrong Password
- [ ] Enter incorrect home Wi-Fi password
- [ ] Provision device
- [ ] **Expected**: Device fails to join home network
- [ ] **Expected**: Device returns to AP mode after timeout

#### Test 9: Special Characters in Password
- [ ] Use password with special chars: `!@#$%^&*()`
- [ ] Provision device
- [ ] **Expected**: Device joins home network successfully

#### Test 10: Multiple Devices
- [ ] Provision 2-3 devices in sequence
- [ ] **Expected**: All devices provision successfully
- [ ] **Expected**: No interference between devices

---

## Regression Testing

### Verify Existing Features Still Work
- [ ] Device discovery on home network
- [ ] Device control (on/off, brightness, etc.)
- [ ] MQTT communication
- [ ] Room management
- [ ] User authentication
- [ ] Settings/preferences

---

## Performance Testing

### Metrics to Monitor
- [ ] Connection time to SoftAP: < 10 seconds
- [ ] Device info fetch time: < 5 seconds
- [ ] Provisioning time: < 10 seconds
- [ ] Disconnect time: < 3 seconds
- [ ] Total provisioning flow: < 60 seconds

---

## Failure Scenarios

### If "Open with" Chooser Appears
1. Check Android version: `adb shell getprop ro.build.version.sdk`
2. Should be ≥29 (Android 10+)
3. Check logcat for "Modern API requires Android 10+"
4. Verify `connectToHbotAPModern` is being called

### If errno=101 Occurs
1. Check logcat for "Successfully bound to SoftAP network"
2. If missing, check for "Failed to bind to SoftAP network"
3. Verify `CHANGE_NETWORK_STATE` permission in manifest
4. Rebuild: `flutter clean && flutter build apk`
5. Check `boundNetwork` is not null

### If Connection Timeout
1. Verify device SoftAP is broadcasting
2. Check SSID is correct (case-sensitive)
3. Move phone closer to device
4. Check Wi-Fi is enabled on phone
5. Check permissions are granted

---

## Production Readiness

### Before Release
- [ ] All tests pass on Android 10+
- [ ] No regressions in existing features
- [ ] Performance metrics acceptable
- [ ] Edge cases handled gracefully
- [ ] Error messages user-friendly
- [ ] Logcat logs appropriate (not too verbose)

### Code Quality
- [ ] No compilation warnings
- [ ] No IDE errors
- [ ] Code follows project style
- [ ] Comments added where needed
- [ ] No debug code left in

### Documentation
- [ ] README updated (if needed)
- [ ] CHANGELOG updated
- [ ] Version number bumped
- [ ] Release notes prepared

---

## Release Process

### Build Release APK
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Verify Release Build
- [ ] APK size reasonable (not bloated)
- [ ] APK signed correctly
- [ ] Test release APK on device
- [ ] All features work in release mode

### Distribution
- [ ] Upload to Play Store (internal testing)
- [ ] Test with internal testers
- [ ] Collect feedback
- [ ] Fix any issues
- [ ] Promote to beta/production

---

## Rollback Plan

### If Critical Issues Found
1. Revert changes:
   ```bash
   git revert <commit-hash>
   ```
2. Rebuild and redeploy previous version
3. Investigate issues
4. Fix and re-test
5. Re-deploy

### Files to Revert
- `android/app/src/main/kotlin/com/example/hbot/EnhancedWiFiPlugin.kt`
- `android/app/src/main/res/xml/network_security_config.xml`
- `android/app/src/main/AndroidManifest.xml`

---

## Post-Deployment Monitoring

### Metrics to Track
- [ ] Provisioning success rate
- [ ] Connection failure rate
- [ ] Average provisioning time
- [ ] User-reported issues
- [ ] Crash reports (if any)

### User Feedback
- [ ] Monitor app reviews
- [ ] Check support tickets
- [ ] Collect user feedback
- [ ] Address issues promptly

---

## Success Criteria

### ✅ Deployment Successful If:
1. ✅ No "Open with" chooser on Android 10-14
2. ✅ No errno=101 errors
3. ✅ Provisioning success rate > 95%
4. ✅ No increase in crash rate
5. ✅ No regressions in existing features
6. ✅ Positive user feedback
7. ✅ Average provisioning time < 60 seconds

---

## Sign-Off

### Development Team
- [ ] Code reviewed
- [ ] Tests passed
- [ ] Documentation complete
- [ ] Ready for QA

### QA Team
- [ ] All test cases passed
- [ ] Edge cases verified
- [ ] Performance acceptable
- [ ] Ready for release

### Product Owner
- [ ] Features verified
- [ ] User experience acceptable
- [ ] Ready for production

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Version**: _______________
**Status**: ⬜ Pending | ⬜ In Progress | ⬜ Complete | ⬜ Rolled Back
