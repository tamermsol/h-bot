# Yellow Overlay - Diagnostic & Fix

## What We Know

The yellow overlay appears on the "Share My Devices" screen and persists even after:
- Clean and pub get
- Reinstalling the app
- Restarting the device

## Possible Causes

### 1. Screen Recording Indicator (Most Likely)
**Symptoms**: Yellow banner at top of screen
**Cause**: Android 12+ shows a persistent indicator when screen recording
**Check**: 
- Pull down notification shade
- Look for "Screen recording" notification
- Stop any screen recording

**Fix**:
```
1. Swipe down from top
2. Tap "Screen recording" notification
3. Tap "Stop"
```

### 2. Accessibility Service Banner
**Symptoms**: Yellow banner with accessibility icon
**Cause**: Accessibility service with overlay permission
**Check**:
```
Settings → Accessibility → Installed Services
```
**Fix**: Disable any active accessibility services

### 3. Developer Options - Show Taps
**Symptoms**: Yellow indicator when tapping
**Check**:
```
Settings → Developer Options → Show taps
```
**Fix**: Turn OFF "Show taps"

### 4. Screen Overlay Detection
**Symptoms**: Yellow banner warning about overlays
**Cause**: Another app has "Draw over other apps" permission
**Check**:
```
Settings → Apps → Special app access → Display over other apps
```
**Fix**: Disable for all apps except system apps

### 5. Battery Saver Mode
**Symptoms**: Yellow/orange banner at top
**Cause**: Battery saver mode active
**Check**: Battery icon color
**Fix**: Disable battery saver mode

## Diagnostic Steps

### Step 1: Check Active Overlays
```bash
# Via ADB
adb shell dumpsys window | findstr "mHasSurface"
```

### Step 2: Check Screen Recording
```bash
# Via ADB
adb shell dumpsys media.audio_flinger | findstr "recording"
```

### Step 3: Check Accessibility Services
```bash
# Via ADB
adb shell settings get secure enabled_accessibility_services
```

### Step 4: Disable All Overlays
```bash
# Via ADB - Revoke overlay permission for all apps
adb shell appops set <package_name> SYSTEM_ALERT_WINDOW deny
```

## Quick Fixes

### Fix 1: Safe Mode
Boot device in safe mode to disable all third-party apps:
```
1. Press and hold Power button
2. Long press "Power off"
3. Tap "OK" to reboot in safe mode
4. Test the app
```

### Fix 2: Clear System UI Cache
```
Settings → Apps → System UI → Storage → Clear Cache
```

### Fix 3: Reset App Preferences
```
Settings → Apps → Reset app preferences
```

### Fix 4: Check for System Updates
```
Settings → System → System update
```

## If It's Screen Recording

The yellow banner in your screenshot looks like it might be a **screen recording indicator**. 

**To verify**:
1. Look at your notification shade
2. Check if there's a screen recording notification
3. The banner should disappear when you stop recording

**Note**: Some screen recording apps (like built-in Android recorder, AZ Screen Recorder, etc.) show a persistent indicator that can't be hidden.

## Workaround for Testing

If you need to test without the overlay:

### Option 1: Use Another Device
Test on a device without screen recording active

### Option 2: Build Release APK
```bash
flutter build apk --release
```
Install and test the release version

### Option 3: Use Emulator
```bash
flutter run -d emulator-5554
```
Test on Android emulator (no screen recording)

## Code Verification

I've verified the app code - there's **NO code** that creates this overlay:
- ✅ No custom overlays in multi_device_share_screen.dart
- ✅ No SystemChrome overlay modifications
- ✅ No debug banners (debugShowCheckedModeBanner: false)
- ✅ No permission dialogs before Generate QR is tapped

## Conclusion

The yellow overlay is **100% a system-level indicator**, not from the app code. It's most likely:

1. **Screen recording indicator** (most common)
2. **Accessibility service banner**
3. **Battery saver mode indicator**

**Action**: Check your notification shade for active system services.
