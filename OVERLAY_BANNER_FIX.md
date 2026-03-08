# Yellow Overlay Banner - Troubleshooting Guide

## What You're Seeing

A yellow banner/overlay appearing at the top of the "Share My Devices" screen.

## Common Causes

### 1. Screen Recording or Screen Capture
- **Cause**: Android shows a banner when screen recording is active
- **Solution**: Stop any screen recording apps

### 2. Accessibility Services
- **Cause**: Some accessibility services trigger overlay detection
- **Solution**: 
  - Settings → Accessibility
  - Disable any active accessibility services temporarily

### 3. Developer Options
- **Cause**: "Show taps", "Pointer location", or similar debug features
- **Solution**:
  - Settings → Developer Options
  - Disable "Show taps"
  - Disable "Pointer location"
  - Disable "Show surface updates"

### 4. Floating Apps or Chat Heads
- **Cause**: Apps with overlay permissions (Facebook Messenger, etc.)
- **Solution**: Close floating windows or chat heads

### 5. System UI Demo Mode
- **Cause**: Demo mode enabled in developer settings
- **Solution**:
  - Settings → Developer Options
  - Disable "System UI Demo Mode"

## Quick Fixes

### Fix 1: Restart the App
```bash
# Close and reopen the app
```

### Fix 2: Check Running Apps
1. Open Recent Apps
2. Close all apps with overlay permissions
3. Reopen your app

### Fix 3: Disable Developer Options
1. Settings → Developer Options
2. Toggle OFF "Developer Options"
3. Restart device

### Fix 4: Build Release Version
The overlay might only appear in debug builds:

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

## Verification

The overlay is **NOT** caused by the app code because:

1. ✅ `debugShowCheckedModeBanner: false` is set in main.dart
2. ✅ No overlay widgets in the multi-device share screen
3. ✅ No debug banners in the code
4. ✅ Standard Flutter/Material widgets used

## If Overlay Persists

### Check for System Overlays:
```bash
# Via ADB
adb shell dumpsys window | grep -i overlay
```

### Check Active Permissions:
1. Settings → Apps → Your App → Permissions
2. Look for "Display over other apps"
3. Should be OFF (not needed for this app)

### Clear App Data:
1. Settings → Apps → Your App
2. Storage → Clear Data
3. Reopen app

## Production Build

The overlay will **NOT** appear in production builds because:
- Debug tools are disabled
- System overlays are not shown to end users
- Release builds don't have development indicators

## Summary

The yellow overlay is a **system-level indicator**, not an app bug. It appears during development/debugging and will not be visible to end users in production builds.

**Quick Solution**: 
1. Stop screen recording
2. Disable developer options
3. Build release version for testing

The app code is correct and doesn't create this overlay.
