# iOS Platform Support - Quick Reference

## ✅ What's Fixed

### Permissions (Info.plist)
- ✅ Location (NSLocationWhenInUseUsageDescription)
- ✅ Local Network (NSLocalNetworkUsageDescription)
- ✅ Bonjour Services (NSBonjourServices)
- ✅ Notifications (NSUserNotificationsUsageDescription)

### Code Updates
- ✅ WiFiPermissionService - iOS permission checks
- ✅ EnhancedWiFiService - iOS Wi-Fi operations
- ✅ WiFiProvisioningService - iOS permission handling
- ✅ AddDeviceFlowScreen - iOS settings integration
- ✅ PlatformService - Already had iOS support

## 🔍 Quick Check

### Is iOS Supported?
```dart
// ✅ GOOD - Checks both platforms
if (isAndroid) {
  // Android-specific code
} else if (isIOS) {
  // iOS-specific code
}

// ❌ BAD - Only checks Android
if (isAndroid) {
  // Android-specific code
}
// iOS falls through with no handling
```

### Permission Checks
```dart
// ✅ GOOD - Platform-specific
if (isIOS) {
  final status = await Permission.locationWhenInUse.status;
} else if (isAndroid) {
  final status = await Permission.location.status;
}

// ❌ BAD - Android-only
if (isAndroid) {
  final status = await Permission.location.status;
}
```

## 📱 iOS Limitations

### Cannot Do on iOS:
- ❌ Programmatic Wi-Fi connection
- ❌ Wi-Fi network scanning
- ❌ Automatic network switching

### Can Do on iOS:
- ✅ Read current Wi-Fi SSID (with location permission)
- ✅ Open Settings app to Wi-Fi page
- ✅ Detect connection status
- ✅ Send HTTP requests to device
- ✅ Local network discovery (with permission)

## 🛠️ Common Patterns

### Reading Wi-Fi SSID
```dart
// Works on both platforms
final ssid = await enhancedWiFiService.getCurrentSSID();
if (ssid == null) {
  // Permission denied or SSID unavailable
  // Show manual entry option
}
```

### Connecting to Device AP
```dart
if (isAndroid) {
  // Automatic connection
  await enhancedWiFiService.connectToHbotAP(ssid);
} else if (isIOS) {
  // Manual connection - guide user
  await PlatformService.openWiFiSettings();
  // Show instructions to user
}
```

### Checking Permissions
```dart
final status = await WiFiPermissionService.checkPermissions();
if (!status.isGranted) {
  // Request permissions
  final newStatus = await WiFiPermissionService.requestPermissions();
}
```

## 🧪 Testing Checklist

### Must Test on Real iOS Device:
- [ ] Location permission prompt
- [ ] Local network permission prompt
- [ ] SSID reading with permission
- [ ] SSID reading without permission
- [ ] Manual Wi-Fi connection flow
- [ ] Device provisioning
- [ ] Settings app integration

### Simulator Limitations:
- ⚠️ Permissions may not work correctly
- ⚠️ Wi-Fi operations unavailable
- ⚠️ Local network not available

## 📝 User Experience

### Android Flow:
1. Request permissions → 2. Auto-scan → 3. Auto-connect → 4. Provision → 5. Auto-reconnect

### iOS Flow:
1. Request permissions → 2. Guide to Settings → 3. Manual connect → 4. Provision → 5. Guide back to Settings → 6. Manual reconnect

## 🚨 Common Errors

### "Undefined name 'Geolocator'"
**Fix**: Add `import 'package:geolocator/geolocator.dart';`

### "Permission prompt not appearing"
**Fix**: Check Info.plist has usage description key

### "Local network permission not working"
**Fix**: Ensure NSBonjourServices configured in Info.plist

### "Cannot read SSID on iOS"
**Fix**: Request location permission first

## 📚 Documentation Files

- `IOS_SETUP_GUIDE.md` - Complete setup guide
- `IOS_PLATFORM_FIXES_SUMMARY.md` - All changes made
- `IOS_PERMISSIONS_AND_PLATFORM_FIXES.md` - Issues and fixes
- `IOS_QUICK_REFERENCE.md` - This file

## 🎯 Key Takeaways

1. **Always check both platforms**: `if (isAndroid) { } else if (isIOS) { }`
2. **iOS requires manual Wi-Fi steps**: Guide users clearly
3. **Permissions are critical**: Request with clear explanations
4. **Test on real devices**: Simulator has limitations
5. **Graceful degradation**: Handle denied permissions well

## 🔗 Useful Links

- [Apple: Accessing Wi-Fi Information](https://developer.apple.com/documentation/systemconfiguration/1614126-cncopycurrentnetworkinfo)
- [Apple: Local Network Privacy](https://developer.apple.com/videos/play/wwdc2020/10110/)
- [Flutter: Permission Handler](https://pub.dev/packages/permission_handler)
- [Flutter: Network Info Plus](https://pub.dev/packages/network_info_plus)
