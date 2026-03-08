# Troubleshooting: SSID Detection & Provisioning Issues

## Problems

### Issue #1: SSID Auto-Detection Not Working
The app cannot automatically detect your current Wi-Fi network name (SSID):
- The "Wi-Fi Network Name (SSID)" field shows empty
- "Try auto-detect again" button doesn't help
- This happens even after granting all permissions

### Issue #2: Stuck at "Verifying internet connectivity..."
The app gets stuck after detecting the device:
- Device shows "already configured"
- App shows "Verifying internet connectivity..."
- Never completes, even after waiting several minutes

---

## Root Causes

### SSID Detection Failure (Android 13/14)
On Android 13+, SSID can only be read when:
1. ✅ Both "Location" AND "Nearby Wi-Fi Devices" permissions are granted
2. ✅ Location Services are turned ON
3. ✅ App is in the foreground
4. ✅ Wi-Fi info is accessible (timing-dependent)

Even with all permissions, Android 13+ can return `<unknown ssid>` due to privacy restrictions.

### Reconnection Failure
After provisioning, the phone needs to:
1. Unbind from the device AP
2. Reconnect to the user's Wi-Fi network
3. Verify internet connectivity

If step #2 fails, the phone stays on the device AP (no internet) and gets stuck.

---

## Fixes Implemented

### Fix #1: Multi-Method SSID Detection (Android 13/14)
**File**: `android/app/src/main/kotlin/com/example/hbot/EnhancedWiFiPlugin.kt`

- ✅ **Method 1**: Try `NetworkCapabilities.transportInfo` (Android 12+)
- ✅ **Method 2**: Fallback to `WifiManager.connectionInfo` (Android 10-11)
- ✅ **Method 3**: Scan for connected network by BSSID (Android 13+ last resort)
- ✅ Better logging to diagnose failures

### Fix #2: Enhanced SSID Refresh with Permission Checks
**File**: `lib/screens/add_device_flow_screen.dart`

- ✅ Check permissions before attempting SSID detection
- ✅ Detailed logging of permission status
- ✅ Clear user feedback when auto-detection fails
- ✅ Graceful fallback to manual entry

### Fix #3: Provisioning Retry Logic
**File**: `lib/services/enhanced_wifi_service.dart`

- ✅ Retry POST request up to 3 times
- ✅ Progressive delays between retries (300ms, 600ms, 900ms)
- ✅ Better error logging

### Fix #4: Network Settling Delay
**File**: `android/app/src/main/kotlin/com/example/hbot/EnhancedWiFiPlugin.kt`

- ✅ Wait 1 second after binding to SoftAP before HTTP calls
- ✅ Ensures network is fully ready

### Fix #5: Enhanced Reconnection Logging
**File**: `lib/screens/add_device_flow_screen.dart`

- ✅ Log SSID and password status before reconnection
- ✅ Clear error messages when reconnection fails
- ✅ Uses `WifiNetworkSuggestion` (Android 10+) to reconnect
- ✅ Unbinds from device AP first
- ✅ Verifies internet connectivity after reconnection

---

## Testing Steps

### Step 1: Rebuild the App
```bash
flutter clean
flutter pub get
flutter build apk --debug
flutter install
```

### Step 2: Monitor Logs
Open a terminal and run:
```bash
adb logcat -c
adb logcat -s EnhancedWiFi:D flutter:I
```

### Step 3: Test Provisioning Flow
1. Open app → "Add Device"
2. Enter Wi-Fi credentials (or use auto-detect)
3. Scan for devices
4. Select device
5. **Watch the logs**

---

## Expected Log Output

### ✅ Successful Flow:

```
D/EnhancedWiFi: Network available: Network 123
D/EnhancedWiFi: Successfully bound to SoftAP network
D/EnhancedWiFi: Network ready for HTTP traffic
I/flutter: 🔧 Provisioning WiFi to SSID: MyHomeWiFi
I/flutter: 📡 POST body: s1=MyHomeWiFi&p1=Test123%21&save=
I/flutter: 📡 Provisioning response (attempt 1): 200
I/flutter: ✅ WiFi credentials sent successfully on attempt 1
I/flutter: 🔄 Reconnecting to user Wi-Fi: MyHomeWiFi
D/EnhancedWiFi: Reconnecting to user Wi-Fi: MyHomeWiFi using WifiNetworkSuggestion
D/EnhancedWiFi: Network suggestion added successfully
I/flutter: ✅ Reconnection initiated: Reconnecting to MyHomeWiFi...
I/flutter: ✅ Successfully reconnected to MyHomeWiFi
I/flutter: ✅ Device created successfully
```

### ❌ If Stuck at "Verifying internet connectivity":

```
I/flutter: 🔧 Provisioning WiFi to SSID: MyHomeWiFi
I/flutter: ✅ WiFi credentials sent successfully
I/flutter: 🔄 Reconnecting to user Wi-Fi: MyHomeWiFi
D/EnhancedWiFi: Network suggestion added successfully
I/flutter: ⚠️ Reconnection initiated but internet not yet available
[STUCK HERE - No internet connectivity]
```

---

## Manual Workaround (If Automatic Reconnection Fails)

If the app gets stuck:

### Option 1: Manual Reconnection
1. **Pull down notification shade**
2. **Tap Wi-Fi icon**
3. **Select your home Wi-Fi** (e.g., "MyHomeWiFi")
4. **Wait for connection**
5. **Return to app**
6. **Tap "Retry"**

### Option 2: Use Wi-Fi Settings
1. **Open Settings → Wi-Fi**
2. **Disconnect from "hbot-xxxx"** (if still connected)
3. **Connect to your home Wi-Fi**
4. **Return to app**
5. **Tap "Retry"**

---

## Common Issues & Solutions

### Issue 1: "Network suggestion failed"
**Cause**: Android 10+ requires `CHANGE_WIFI_STATE` permission

**Solution**: Check `AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
```

### Issue 2: "Still connected to device AP"
**Cause**: Unbind not working or reconnection not triggered

**Solution**: Check logs for:
```
D/EnhancedWiFi: Process unbound from SoftAP network
```

If missing, the unbind failed. Try:
1. Restart the app
2. Manually disconnect from device AP
3. Retry provisioning

### Issue 3: "Internet not available after reconnection"
**Cause**: Phone reconnected but internet not yet ready

**Solution**: Wait 10-15 seconds. The app retries internet verification up to 6 times with progressive delays.

### Issue 4: "Device already configured"
**Cause**: Device was provisioned in a previous attempt

**Solution**: This is actually **SUCCESS**! The device is already on your Wi-Fi. The app should:
1. Skip provisioning
2. Reconnect phone to user's Wi-Fi
3. Create device in account

If stuck here, manually reconnect to your Wi-Fi and tap "Retry".

---

## Debug Checklist

If provisioning fails, check:

- [ ] **Permissions granted**
  - Location permission
  - Nearby Wi-Fi devices (Android 13+)
  - Location Services ON

- [ ] **Network binding**
  - Log shows: "Successfully bound to SoftAP network"
  - If missing: Network binding failed

- [ ] **Provisioning request**
  - Log shows: "📡 Provisioning response (attempt 1): 200"
  - If 404/500: Device not responding
  - If timeout: Network not bound correctly

- [ ] **Unbinding**
  - Log shows: "Process unbound from SoftAP network"
  - If missing: Unbind failed

- [ ] **Reconnection**
  - Log shows: "Network suggestion added successfully"
  - If "SUGGESTION_FAILED": Permission issue

- [ ] **Internet verification**
  - Log shows: "✅ Successfully reconnected to MyHomeWiFi"
  - If stuck: Manual reconnection needed

---

## Advanced Debugging

### Check Network Binding Status
```bash
adb shell dumpsys connectivity | grep -A 20 "Active default network"
```

Should show your home Wi-Fi after reconnection, not the device AP.

### Check Wi-Fi Connection
```bash
adb shell dumpsys wifi | grep "mWifiInfo"
```

Should show:
- SSID: Your home Wi-Fi (not "hbot-xxxx")
- State: COMPLETED
- Link speed: > 0 Mbps

### Force Reconnection
If stuck, force reconnection via ADB:
```bash
# Disconnect from current network
adb shell svc wifi disable
adb shell svc wifi enable

# Wait 5 seconds
# Phone should auto-reconnect to saved Wi-Fi
```

---

## Next Steps

### If Still Stuck After Rebuild:

1. **Capture full logs**:
   ```bash
   adb logcat > provisioning_logs.txt
   ```

2. **Check for errors**:
   - Search for "EnhancedWiFi" in logs
   - Search for "ERROR" or "Exception"
   - Look for "Network suggestion" status

3. **Test manual reconnection**:
   - After provisioning, manually reconnect to your Wi-Fi
   - If device appears in account → Automatic reconnection is the only issue
   - If device doesn't appear → Provisioning itself failed

4. **Verify device received credentials**:
   - Power cycle the device
   - Check if device connects to your Wi-Fi
   - If yes → Provisioning worked, only phone reconnection failed
   - If no → Provisioning didn't work (check POST request)

---

## Expected Behavior After Fix

1. ✅ App connects to device AP
2. ✅ App fetches device info
3. ✅ App sends Wi-Fi credentials (POST to /wi)
4. ✅ Device saves credentials and reboots
5. ✅ App unbinds from device AP
6. ✅ **App automatically reconnects to user's Wi-Fi** ← KEY FIX
7. ✅ App verifies internet connectivity
8. ✅ App creates device in account
9. ✅ Device appears online
10. ✅ Success screen shown

**Total time**: 30-60 seconds (no manual intervention needed)

---

## Summary

The key fix is **automatic reconnection to user's Wi-Fi** using `WifiNetworkSuggestion`. This eliminates the need for manual reconnection and makes the provisioning flow seamless.

If automatic reconnection fails, the app now provides clear instructions for manual reconnection and a "Retry" button to continue.

**Rebuild the app and test!** The provisioning flow should now complete automatically without getting stuck.
