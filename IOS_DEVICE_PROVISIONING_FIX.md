# iOS Device Provisioning Fix

## Problem
Device provisioning gets stuck on iPhone because iOS has strict WiFi and local network restrictions that require manual user actions.

## Root Cause
Unlike Android, iOS **does not allow** apps to:
- Programmatically scan for WiFi networks
- Programmatically connect to WiFi networks
- Access local network without explicit permission prompt

## What iOS Requires

### 1. Location Permission (✅ Already Working)
- Needed to read WiFi SSID
- Requested when app opens
- User chose "Allow While Using App"

### 2. Local Network Permission (❌ Missing)
- Needed to communicate with devices on 192.168.4.1
- Triggered automatically when app tries to access local network
- **Must be granted for provisioning to work**

### 3. Manual WiFi Connection (❌ Not Guided)
- User must manually connect to device's "hbot-XXXX" network in Settings
- App cannot do this programmatically on iOS

## Solution Applied

### 1. Updated Info.plist
- Enhanced `NSLocalNetworkUsageDescription` with clearer explanation
- Added proper Bonjour service entries (with trailing dots) to trigger local network permission

### 2. User Workflow for iOS

The app needs to guide users through this iOS-specific flow:

#### Step 1: WiFi Setup (Current)
- User enters their home WiFi credentials
- ✅ This part works fine

#### Step 2: Device Discovery (NEEDS FIX)
**Current behavior:** App tries to scan for device networks (fails silently on iOS)

**Required behavior:**
1. Show iOS-specific instructions:
   ```
   On iPhone, you need to manually connect to your device:
   
   1. Put your device in pairing mode (LED blinking)
   2. Open iPhone Settings > WiFi
   3. Look for network named "hbot-XXXX"
   4. Tap to connect (no password needed)
   5. Return to this app
   ```

2. App should detect when user returns and check if connected to hbot-* network

3. When user tries to access 192.168.4.1, iOS will show local network permission prompt:
   ```
   "HBOT" Would Like to Find and Connect to Devices on Your Local Network
   
   [Don't Allow]  [OK]
   ```
   User MUST tap [OK]

#### Step 3: Provisioning
- Once connected to device network AND local network permission granted
- App can communicate with 192.168.4.1
- Send WiFi credentials
- Device reboots and connects to home WiFi

#### Step 4: Return to Home WiFi (NEEDS FIX)
**Current behavior:** App tries to programmatically reconnect (fails on iOS)

**Required behavior:**
1. Show instructions:
   ```
   Device is connecting to your WiFi...
   
   Please reconnect your iPhone to your home WiFi:
   1. Open Settings > WiFi
   2. Select "[Your WiFi Name]"
   3. Return to this app
   ```

2. App polls to detect when back on home WiFi
3. Verify device is online and responding

## Code Changes Needed

### 1. Update Device Discovery Screen for iOS

```dart
// In _buildDeviceDiscoveryStep()
if (isIOS) {
  return _buildIOSManualConnectionGuide();
} else {
  return _buildAndroidAutoDiscovery();
}
```

### 2. Add iOS Manual Connection Guide

```dart
Widget _buildIOSManualConnectionGuide() {
  return Padding(
    padding: const EdgeInsets.all(AppTheme.paddingLarge),
    child: Column(
      children: [
        Icon(Icons.settings, size: 80, color: AppTheme.primaryColor),
        SizedBox(height: AppTheme.paddingLarge),
        
        Text(
          'Connect to Your Device',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        
        SizedBox(height: AppTheme.paddingMedium),
        
        Text(
          'On iPhone, you need to manually connect to your device\'s WiFi network:',
          textAlign: TextAlign.center,
        ),
        
        SizedBox(height: AppTheme.paddingLarge),
        
        _buildStep(1, 'Put your device in pairing mode', 'LED should be blinking rapidly'),
        _buildStep(2, 'Open iPhone Settings > WiFi', 'Tap the Settings app'),
        _buildStep(3, 'Look for "hbot-XXXX" network', 'XXXX will be numbers'),
        _buildStep(4, 'Tap to connect', 'No password needed'),
        _buildStep(5, 'Return to this app', 'Tap "I\'m Connected" below'),
        
        Spacer(),
        
        if (_isLoading)
          CircularProgressIndicator()
        else
          ElevatedButton(
            onPressed: _checkIOSDeviceConnection,
            child: Text('I\'m Connected'),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        
        SizedBox(height: AppTheme.paddingMedium),
        
        TextButton(
          onPressed: () {
            // Open iOS Settings app
            openAppSettings();
          },
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}

Widget _buildStep(int number, String title, String subtitle) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primaryColor,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ],
    ),
  );
}

Future<void> _checkIOSDeviceConnection() async {
  setState(() {
    _isLoading = true;
    _statusMessage = 'Checking connection...';
  });
  
  try {
    // Check if connected to hbot network
    final ssid = await _wifiService.getCurrentSSID();
    if (ssid == null || !ssid.toLowerCase().startsWith('hbot')) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Not connected to device network. Please connect to hbot-XXXX in Settings.';
      });
      return;
    }
    
    // Try to fetch device info (this will trigger local network permission)
    final deviceInfo = await _wifiService.fetchDeviceInfo();
    
    setState(() {
      _discoveredDevice = deviceInfo;
      _isConnectedToDevice = true;
      _currentStep = PairingStep.provisioning;
    });
    
    // Start provisioning
    await _provisionDevice();
    
  } catch (e) {
    setState(() {
      _isLoading = false;
      _statusMessage = 'Error: $e\n\nMake sure you granted "Local Network" permission when prompted.';
    });
  }
}
```

### 3. Add iOS Reconnection Guide

```dart
// After provisioning, guide user back to home WiFi
if (isIOS) {
  _showIOSReconnectionDialog();
}

void _showIOSReconnectionDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Reconnect to Home WiFi'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your device is now connecting to $_currentSSID'),
          SizedBox(height: 16),
          Text('Please reconnect your iPhone:'),
          SizedBox(height: 8),
          Text('1. Open Settings > WiFi'),
          Text('2. Select "$_currentSSID"'),
          Text('3. Return to this app'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            openAppSettings();
          },
          child: Text('Open Settings'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _verifyDeviceOnline();
          },
          child: Text('I\'m Reconnected'),
        ),
      ],
    ),
  );
}
```

## Testing Steps

1. **Clean install** the app on iPhone
2. Open app - should request location permission → Grant it
3. Go to Add Device flow
4. Enter WiFi credentials → Tap Next
5. **iOS-specific flow should appear** with manual connection instructions
6. Follow instructions to connect to hbot-XXXX in Settings
7. Return to app → Tap "I'm Connected"
8. **Local network permission prompt should appear** → Tap OK
9. Provisioning should proceed
10. Follow instructions to reconnect to home WiFi
11. Device should appear in app

## Troubleshooting

### "Stuck on searching" screen
- App is trying to scan WiFi (not possible on iOS)
- **Fix:** Implement iOS-specific manual connection guide

### "Cannot connect to device" error
- User didn't grant local network permission
- **Fix:** Show clear message about granting permission, offer to retry

### "Device not found after provisioning"
- iPhone still connected to device network
- **Fix:** Guide user to reconnect to home WiFi

### Local network permission not appearing
- Bonjour services not properly configured
- **Fix:** Ensure Info.plist has services with trailing dots (already applied)

## Key Differences: iOS vs Android

| Feature | Android | iOS |
|---------|---------|-----|
| Scan WiFi networks | ✅ Yes (with permission) | ❌ No |
| Connect to WiFi | ✅ Yes (Android 10+) | ❌ No |
| Read current SSID | ✅ Yes (with permission) | ✅ Yes (with permission) |
| Local network access | ✅ Automatic | ⚠️ Requires permission prompt |
| User action required | Minimal | Manual WiFi switching |

## References

- [Apple Local Network Privacy](https://developer.apple.com/videos/play/wwdc2020/10110/)
- [NEHotspotConfiguration](https://developer.apple.com/documentation/networkextension/nehotspotconfiguration) (requires special entitlement)
- [Network Extension Framework](https://developer.apple.com/documentation/networkextension)
