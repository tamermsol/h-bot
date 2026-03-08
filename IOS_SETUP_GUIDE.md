# iOS Setup and Configuration Guide

## Overview
This guide covers iOS-specific setup, permissions, and limitations for the HBOT smart home app.

## iOS Permissions Configured

### 1. Location Permission (NSLocationWhenInUseUsageDescription)
**Required for**: Reading Wi-Fi SSID (network name)
**Reason**: Apple requires location permission to access Wi-Fi information for privacy reasons
**User message**: "HBOT needs access to your location to read Wi-Fi network names (SSID) when adding new devices to your smart home."

### 2. Local Network Permission (NSLocalNetworkUsageDescription)
**Required for**: Device discovery and communication on local network
**Reason**: iOS 14+ requires explicit permission for local network access
**User message**: "HBOT needs access to your local network to discover, configure, and control your smart home devices."

### 3. Bonjour Services (NSBonjourServices)
**Required for**: mDNS/Bonjour device discovery
**Services configured**:
- `_http._tcp` - HTTP services
- `_tasmota._tcp` - Tasmota device discovery
- `_hbot._tcp` - HBOT device discovery

### 4. Notifications (NSUserNotificationsUsageDescription)
**Required for**: Push notifications about device status and automations
**User message**: "HBOT would like to send you notifications about device status, automations, and important updates."

### 5. Background Modes
**Configured modes**:
- `fetch` - Background fetch for updates
- `processing` - Background processing tasks

## iOS Limitations and Workarounds

### Wi-Fi Connection Limitations

#### What iOS CANNOT Do:
1. **Programmatic Wi-Fi Connection**: Apps cannot automatically connect to Wi-Fi networks
2. **Wi-Fi Scanning**: Apps cannot scan for available Wi-Fi networks
3. **Network Switching**: Apps cannot switch between networks automatically

#### Workarounds Implemented:

1. **Manual Connection Flow**:
   - App detects when manual connection is needed
   - Opens iOS Settings app to Wi-Fi page
   - Guides user through manual connection steps
   - Detects when connection is successful

2. **NEHotspotConfiguration (iOS 11+)**:
   - Can suggest Wi-Fi networks to iOS
   - User still needs to approve connection
   - Works for WPA/WPA2 networks
   - Not implemented yet but recommended for future

3. **SSID Detection**:
   - App can read current Wi-Fi SSID (with location permission)
   - Used to verify successful connections
   - Fallback to manual entry if permission denied

### Device Provisioning on iOS

#### Recommended Flow:
1. **Detect Device AP**: App reads current SSID to check if connected to device
2. **Manual Connection**: If not connected, guide user to Settings
3. **Provision Device**: Once connected, send Wi-Fi credentials via HTTP
4. **Manual Reconnection**: Guide user back to Settings to reconnect to home Wi-Fi
5. **Verify Connection**: Check for internet connectivity

#### User Experience:
- More manual steps than Android
- Clear instructions at each step
- Visual indicators for connection status
- Automatic detection when steps are complete

## Code Changes for iOS Support

### 1. WiFiPermissionService
- Added iOS location permission checks
- iOS-specific permission request flow
- Platform-specific error messages

### 2. EnhancedWiFiService
- iOS SSID reading via network_info_plus
- Manual connection guidance for iOS
- Platform-specific error handling
- Graceful fallbacks when features unavailable

### 3. WiFiProvisioningService
- iOS permission checks
- Manual connection flow support
- Platform-specific provisioning steps

### 4. AddDeviceFlowScreen
- iOS-specific UI guidance
- Manual connection instructions
- Settings app integration

### 5. PlatformService
- iOS Settings URL schemes
- Wi-Fi settings deep linking
- Fallback to general settings

## Testing on iOS

### Required Test Scenarios:

1. **Permission Requests**:
   - [ ] Location permission prompt appears
   - [ ] Local network permission prompt appears
   - [ ] Notification permission prompt appears
   - [ ] Proper handling of denied permissions

2. **Wi-Fi Operations**:
   - [ ] SSID reading with location permission
   - [ ] SSID reading without location permission (graceful fallback)
   - [ ] Manual connection flow to device AP
   - [ ] Manual reconnection to home Wi-Fi
   - [ ] Connection status detection

3. **Device Provisioning**:
   - [ ] Connect to device AP manually
   - [ ] Send Wi-Fi credentials to device
   - [ ] Device connects to home network
   - [ ] App reconnects to home network
   - [ ] Device discovery after provisioning

4. **Settings Integration**:
   - [ ] Open Wi-Fi settings from app
   - [ ] Open general settings from app
   - [ ] Return to app after settings changes

## iOS Deployment Checklist

### Before Submitting to App Store:

1. **Info.plist**:
   - [ ] All permission descriptions are clear and user-friendly
   - [ ] Bonjour services are correctly configured
   - [ ] Background modes are justified in review notes

2. **Privacy**:
   - [ ] Location permission only requested when needed
   - [ ] Clear explanation of why each permission is needed
   - [ ] Privacy policy updated with iOS-specific permissions

3. **User Experience**:
   - [ ] Manual connection flows are intuitive
   - [ ] Clear instructions for each step
   - [ ] Error messages are helpful
   - [ ] Fallbacks work when permissions denied

4. **Testing**:
   - [ ] Test on multiple iOS versions (14+)
   - [ ] Test on iPhone and iPad
   - [ ] Test with permissions denied
   - [ ] Test with location services disabled
   - [ ] Test with airplane mode

## Common iOS Issues and Solutions

### Issue: "Cannot read Wi-Fi SSID"
**Solution**: 
- Ensure location permission is granted
- Ensure location services are enabled
- Check Info.plist has NSLocationWhenInUseUsageDescription

### Issue: "Local network permission not appearing"
**Solution**:
- Ensure NSLocalNetworkUsageDescription is in Info.plist
- Ensure NSBonjourServices are configured
- Permission appears on first local network access

### Issue: "Cannot connect to device AP"
**Solution**:
- iOS requires manual connection
- Guide user to Settings > Wi-Fi
- Provide clear step-by-step instructions
- Detect when connection is successful

### Issue: "App crashes when requesting permissions"
**Solution**:
- Ensure all permission descriptions are in Info.plist
- Check for missing usage description keys
- Test on physical device (not simulator)

## Future Enhancements for iOS

### Recommended Improvements:

1. **NEHotspotConfiguration**:
   - Implement for smoother Wi-Fi provisioning
   - Reduces manual steps for users
   - Better user experience

2. **Network Extension**:
   - Consider for advanced network features
   - Requires special entitlements
   - May need Apple approval

3. **HomeKit Integration**:
   - Native iOS smart home integration
   - Better Siri support
   - Improved user trust

4. **Shortcuts Integration**:
   - iOS Shortcuts for automations
   - Siri voice commands
   - Better iOS ecosystem integration

## Resources

- [Apple Documentation: Accessing Wi-Fi Information](https://developer.apple.com/documentation/systemconfiguration/1614126-cncopycurrentnetworkinfo)
- [NEHotspotConfiguration](https://developer.apple.com/documentation/networkextension/nehotspotconfiguration)
- [Local Network Privacy](https://developer.apple.com/videos/play/wwdc2020/10110/)
- [Permission Best Practices](https://developer.apple.com/design/human-interface-guidelines/privacy)
