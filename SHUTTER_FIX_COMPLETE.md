# Shutter Device Detection & Routing - COMPLETE FIX

## 🎯 Problem Identified

Your shutter device was being detected as a **2-Channel Relay** instead of a **Shutter** because:

1. ❌ Channel detection counted relay outputs (2 relays for shutter motor)
2. ❌ Device type was only determined by device NAME, not actual capabilities
3. ❌ No STATUS 8 analysis to detect `Shutter1` field from Tasmota
4. ✅ UI routing was already in place but never triggered

## ✅ Complete Solution Implemented

### 1. **Enhanced Channel Detection** (`lib/utils/channel_detection_utils.dart`)

**Added shutter detection method:**
```dart
/// Detect if device is a shutter/blind device
/// Checks STATUS 8 (StatusSNS) for Shutter1 field or StatusSHT
static bool isShutterDevice(Map<String, dynamic> status) {
  // Check StatusSNS for Shutter1
  final statusSNS = status['StatusSNS'] as Map<String, dynamic>?;
  if (statusSNS != null) {
    if (statusSNS.containsKey('Shutter1') || statusSNS.containsKey('StatusSHT')) {
      return true;
    }
  }

  // Check root level for Shutter1 (from RESULT messages)
  if (status.containsKey('Shutter1')) {
    return true;
  }

  // Check SetOption80 (shutter mode enabled)
  final statusSTO = status['StatusSTO'] as Map<String, dynamic>?;
  if (statusSTO != null && statusSTO['SetOption80'] == 1) {
    return true;
  }

  return false;
}
```

**Modified channel detection to prioritize shutters:**
```dart
static int detectChannelCount(Map<String, dynamic> status) {
  // PRIORITY: Check if this is a shutter device first
  // Shutters should always be treated as 1-channel devices
  if (isShutterDevice(status)) {
    debugPrint('🪟 Detected SHUTTER device - returning 1 channel');
    return 1;
  }
  
  // ... rest of detection logic
}
```

---

### 2. **Device Discovery Enhancement** (`lib/services/device_discovery_service.dart`)

**Added STATUS 8 analysis during provisioning:**
```dart
// Get sensor information AND check for shutter device
final sensors = <String>[];
Map<String, dynamic>? status8Data;
try {
  final sensorResponse = await http
      .get(Uri.http('$ip:80', '/cm', {'cmnd': 'Status 8'}))
      .timeout(_httpTimeout);

  if (sensorResponse.statusCode == 200) {
    final sensorData = jsonDecode(sensorResponse.body) as Map<String, dynamic>;
    status8Data = sensorData; // Store for shutter detection
    final statusSNS = sensorData['StatusSNS'] ?? {};
    sensors.addAll(
      statusSNS.keys.where((key) => key != 'Time').cast<String>(),
    );
  }
} catch (e) {
  // Sensor info not available
}

// Check if this is a shutter device using STATUS 8 data
bool isShutter = false;
if (status8Data != null) {
  isShutter = ChannelDetectionUtils.isShutterDevice(status8Data);
  if (isShutter) {
    debugPrint('🪟 Device detected as SHUTTER from STATUS 8');
    channels = 1; // Override channel count for shutters
  }
}
```

---

### 3. **Device Model Update** (`lib/models/tasmota_device_info.dart`)

**Added isShutter flag:**
```dart
class TasmotaDeviceInfo {
  final String ip;
  final String mac;
  final String hostname;
  final String module;
  final String version;
  final int channels;
  final List<String> sensors;
  final String topicBase;
  final String fullTopic;
  final Map<String, dynamic> status;
  final bool isShutter; // NEW: Flag to indicate if device is a shutter

  const TasmotaDeviceInfo({
    required this.ip,
    required this.mac,
    required this.hostname,
    required this.module,
    required this.version,
    required this.channels,
    required this.sensors,
    required this.topicBase,
    required this.fullTopic,
    required this.status,
    this.isShutter = false, // Default to false for backward compatibility
  });
}
```

---

### 4. **Provisioning Flow Update** (`lib/screens/add_device_flow_screen.dart`)

**Enhanced device type determination:**
```dart
DeviceType _determineDeviceType(
  String deviceName, {
  TasmotaDeviceInfo? deviceInfo,
}) {
  // PRIORITY: Check if device info indicates shutter
  if (deviceInfo?.isShutter == true) {
    debugPrint('🪟 Device type determined as SHUTTER from device info');
    return DeviceType.shutter;
  }

  // Fallback to name-based detection
  final name = deviceName.toLowerCase();
  if (name.contains('light') || name.contains('bulb')) {
    return DeviceType.dimmer;
  } else if (name.contains('sensor')) {
    return DeviceType.sensor;
  } else if (name.contains('shutter') || name.contains('blind')) {
    return DeviceType.shutter;
  }
  return DeviceType.relay;
}
```

**Updated call site:**
```dart
// Determine device type (pass deviceInfo for shutter detection)
DeviceType deviceType = _determineDeviceType(
  deviceInfo.module,
  deviceInfo: deviceInfo,
);
```

---

### 5. **UI Routing** (Already in place! ✅)

**File**: `lib/widgets/enhanced_device_control_widget.dart`

```dart
// Channel controls - different UI for shutter devices
if (widget.device.deviceType == DeviceType.shutter)
  ShutterControlWidget(
    device: widget.device,
    mqttManager: _mqttManager,
    shutterIndex: 1,
  )
else if (widget.device.channels == 1)
  _buildSingleChannelControl(isConnected)
else
  _buildMultiChannelControls(isConnected),

// Multi-channel bulk controls (not for shutters)
if (widget.device.deviceType != DeviceType.shutter &&
    widget.device.channels > 1) ...[
  const SizedBox(height: AppTheme.paddingMedium),
  _buildBulkControls(isConnected),
],
```

---

## 🔄 Data Flow

### Provisioning Flow (New Device)

```
1. User connects to device AP
   ↓
2. App sends Status 0 command
   ↓
3. App sends Status 8 command ← NEW: Analyzes for Shutter1
   ↓
4. ChannelDetectionUtils.isShutterDevice() checks:
   - StatusSNS.Shutter1 ✓
   - StatusSHT ✓
   - SetOption80 ✓
   ↓
5. If shutter detected:
   - channels = 1
   - isShutter = true
   ↓
6. Device created with:
   - device_type = 'shutter'
   - channel_count = 1
   ↓
7. UI automatically shows ShutterControlWidget
```

### Runtime Flow (Existing Device)

```
1. User opens device control screen
   ↓
2. EnhancedDeviceControlWidget checks device.deviceType
   ↓
3. If deviceType == DeviceType.shutter:
   → Render ShutterControlWidget
   → Show slider + 3 buttons (Close, Stop, Open)
   ↓
4. User interacts with controls:
   - Tap Open → cmnd/{topic}/ShutterOpen1
   - Tap Close → cmnd/{topic}/ShutterClose1
   - Tap Stop → cmnd/{topic}/ShutterStop1
   - Drag slider to 50% → cmnd/{topic}/ShutterPosition1 50
```

---

## 🧪 Testing Checklist

### Before Testing
- [ ] Delete existing "Hbot-Shutter" device from database
- [ ] Ensure Tasmota device has `SetOption80 1` enabled
- [ ] Verify shutter is configured: `ShutterRelay1 1`

### Provisioning Test
1. [ ] Start "Add Device" flow
2. [ ] Connect to device AP
3. [ ] Check debug logs for: `🪟 Device detected as SHUTTER from STATUS 8`
4. [ ] Check debug logs for: `🪟 Detected SHUTTER device - returning 1 channel`
5. [ ] Complete provisioning
6. [ ] Verify device shows as "1-Channel Device • Shutter" (not "2-Channel Device • Relay")

### UI Test
1. [ ] Open device control screen
2. [ ] Verify shutter UI is shown (slider + 3 buttons)
3. [ ] Verify NO relay toggle buttons are shown
4. [ ] Verify NO "Channel 1" / "Channel 2" labels

### Control Test
1. [ ] Tap **Close** button → shutter closes
2. [ ] Tap **Stop** button → shutter stops
3. [ ] Tap **Open** button → shutter opens
4. [ ] Drag slider to **30%** → shutter moves to 30%
5. [ ] Verify position display updates in real-time

### MQTT Test
1. [ ] Monitor MQTT traffic (use MQTT Explorer or debug sheet)
2. [ ] Tap Open → verify `cmnd/hbot_XXXXXX/ShutterOpen1` published
3. [ ] Tap Close → verify `cmnd/hbot_XXXXXX/ShutterClose1` published
4. [ ] Tap Stop → verify `cmnd/hbot_XXXXXX/ShutterStop1` published
5. [ ] Set 50% → verify `cmnd/hbot_XXXXXX/ShutterPosition1` with payload `50`

---

## 📊 Expected Results

### Database
```sql
SELECT id, name, device_type, channel_count 
FROM devices 
WHERE name LIKE '%Shutter%';
```

**Expected:**
| id | name | device_type | channel_count |
|----|------|-------------|---------------|
| ... | Hbot-Shutter | shutter | 1 |

### UI Display
- **Device Card**: Shows window icon (🪟)
- **Device Type**: "1-Channel Device • Shutter"
- **Controls**: Slider + 3 buttons (Close, Stop, Open)
- **NO**: Channel 1/Channel 2 toggle buttons
- **NO**: "All ON" / "All OFF" bulk controls

---

## 🐛 Troubleshooting

### Issue: Still shows as 2-channel relay

**Solution:**
1. Delete the device from the app
2. In Tasmota console, verify: `SetOption80` → should return `1`
3. Verify: `ShutterRelay1` → should return `1`
4. Re-provision the device through the app
5. Check debug logs for shutter detection messages

### Issue: Shutter UI not showing

**Check:**
1. Database: `SELECT device_type FROM devices WHERE id = '...'`
2. Should be `'shutter'`, not `'relay'`
3. If wrong, update: `UPDATE devices SET device_type = 'shutter', channel_count = 1 WHERE id = '...'`
4. Restart app

### Issue: Commands not working

**Check:**
1. MQTT connection status (green dot)
2. Device topic base is correct
3. Tasmota console: `Status 8` → should show `Shutter1` field
4. Enable shutter mode: `SetOption80 1`

---

## ✅ Summary

**All fixes are complete and ready to test!**

The system now:
1. ✅ Detects shutter devices during provisioning via STATUS 8 analysis
2. ✅ Sets correct device type (`shutter`) and channel count (`1`)
3. ✅ Routes to shutter UI automatically
4. ✅ Sends correct MQTT commands (`ShutterOpen/Close/Stop/Position`)
5. ✅ Displays proper UI (slider + 3 buttons, no relay toggles)

**Next step**: Delete your existing "Hbot-Shutter" device and re-provision it to see the fix in action!

