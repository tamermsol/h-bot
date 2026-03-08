# iOS Permissions and Platform Support Fixes

## Issues Found

### 1. **Missing iOS Permissions in Info.plist**
The iOS `Info.plist` is missing critical permission descriptions required for:
- Location services (for Wi-Fi SSID reading)
- Local network access (for device discovery and provisioning)
- Notifications

### 2. **Platform-Specific Code Only Supports Android**
Multiple services have `if (isAndroid)` checks that return early or skip functionality for iOS:
- `wifi_permission_service.dart` - Returns "granted" without checking iOS permissions
- `enhanced_wifi_service.dart` - Multiple methods return null or throw "not implemented" for iOS
- `wifi_provisioning_service.dart` - Only checks Android permissions
- `add_device_flow_screen.dart` - Only opens Wi-Fi settings on Android
- `platform_service.dart` - Has iOS support but may need URL scheme updates

### 3. **Missing iOS-Specific Implementations**
- Wi-Fi scanning and connection (iOS has different APIs)
- Location permission handling for iOS
- Nearby devices permission (iOS uses different approach)

## Required iOS Permissions

### Info.plist Keys Needed:
1. **NSLocationWhenInUseUsageDescription** - Required to read Wi-Fi SSID
2. **NSLocationAlwaysAndWhenInUseUsageDescription** - For background location (if needed)
3. **NSLocalNetworkUsageDescription** - Required for local device discovery
4. **NSBonjourServices** - Required for mDNS/Bonjour discovery
5. **NSUserNotificationsUsageDescription** - For push notifications (iOS 10+)

## Fixes Applied

### 1. Update Info.plist with Required Permissions
### 2. Update WiFiPermissionService for iOS Support
### 3. Update EnhancedWiFiService for iOS Support
### 4. Update WiFiProvisioningService for iOS Support
### 5. Update AddDeviceFlowScreen for iOS Support
### 6. Update Platform-Specific Checks Throughout Codebase

## iOS Wi-Fi Limitations

**Important**: iOS has strict limitations on Wi-Fi control:
- Apps cannot programmatically connect to Wi-Fi networks (requires user action)
- Wi-Fi scanning is limited (requires location permission)
- SSID reading requires location permission
- Network configuration must go through Settings app

**Recommended Approach for iOS**:
1. Use NEHotspotConfiguration for Wi-Fi provisioning (iOS 11+)
2. Guide users to manually connect to device AP if needed
3. Use local network permission for device discovery
4. Implement fallback flows for manual configuration
