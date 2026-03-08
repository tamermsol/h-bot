# Dynamic MQTT Topic Detection Fix

## Problem Description

**Issue**: MQTT topic detection was using static/hardcoded approach instead of dynamically extracting the topic from the device during provisioning.

**Previous Implementation**: 
- Used `Status 6` command which returns `StatusMQT` section
- Generated topics from MAC address as fallback
- Channel detection didn't use the `Power` field from basic status

**Required Implementation**:
- Use basic `status` command: `http://192.168.4.1/cm?cmnd=status`
- Extract `Topic` field from `Status` section in response
- Use `Power` field to determine number of channels
- Ensure 2-channel devices get proper status reporting configuration

## Example Response Analysis

**Command**: `http://192.168.4.1/cm?cmnd=status`

**Response**:
```json
{
  "Status": {
    "Module": 0,
    "DeviceName": "Hbot-8ch",
    "FriendlyName": ["Tasmota","Tasmota2","Tasmota3","Tasmota4","tasmota5","tasmota6","tasmota7","tasmota8"],
    "Topic": "hbot_8857CC",
    "ButtonTopic": "0",
    "Power": "00000000",
    "PowerLock": "00000000",
    "PowerOnState": 3,
    "LedState": 1,
    "LedMask": "FFFF",
    "SaveData": 1,
    "SaveState": 1,
    "SwitchTopic": "0",
    "SwitchMode": [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    "ButtonRetain": 0,
    "SwitchRetain": 0,
    "SensorRetain": 0,
    "PowerRetain": 0,
    "InfoRetain": 0,
    "StateRetain": 0,
    "StatusRetain": 0
  }
}
```

**Key Fields**:
- `Status.Topic`: `"hbot_8857CC"` - The MQTT topic base
- `Status.Power`: `"00000000"` - 8 characters = 8 channels
- `Status.DeviceName`: `"Hbot-8ch"` - Device name
- `Status.FriendlyName`: Array of 8 names = 8 channels

## Solution Implemented

### **1. Dynamic Topic Extraction**

**File**: `lib/services/device_discovery_service.dart`

**Before**:
```dart
// Used Status 6 command
final mqttResponse = await http.get(Uri.http('$ip:80', '/cm', {'cmnd': 'Status 6'}));
final statusMQT = mqttData['StatusMQT'] ?? {};
topicBase = statusMQT['Topic'] ?? '';
```

**After**:
```dart
// Use basic status command as specified
final mqttResponse = await http.get(Uri.http('$ip:80', '/cm', {'cmnd': 'status'}));
final statusSection = mqttData['Status'] ?? {};
topicBase = statusSection['Topic'] ?? '';

debugPrint('🔍 Extracted MQTT topic from device: $topicBase');
debugPrint('📋 Full status response: $mqttData');
```

### **2. Enhanced Channel Detection**

**File**: `lib/utils/channel_detection_utils.dart`

**New Method**: `_detectFromStatusPower()`
```dart
static int _detectFromStatusPower(Map<String, dynamic> status) {
  final statusSection = status['Status'] as Map<String, dynamic>?;
  if (statusSection == null) return 0;

  final powerField = statusSection['Power'];
  if (powerField == null) return 0;

  final powerString = powerField.toString();
  debugPrint('🔍 Analyzing Power field: $powerString');

  // Power field contains binary representation of channel states
  // e.g., "00000000" for 8 channels all OFF, "11" for 2 channels
  // The length indicates the number of channels
  if (powerString.isNotEmpty) {
    final channelCount = powerString.length;
    debugPrint('📊 Power field length indicates $channelCount channels');
    return channelCount;
  }

  return 0;
}
```

**Detection Priority**:
1. **Status.Power field** (most reliable for basic status)
2. **StatusSTS.POWER states** (fallback)
3. **FriendlyName array** (secondary)
4. **GPIO configuration** (tertiary)
5. **Module type** (last resort)

### **3. 2-Channel Device Specific Configuration**

**File**: `lib/services/enhanced_mqtt_service.dart`

**Added 2-Channel Specific Settings**:
```dart
if (device.channels == 2) {
  // Additional configuration for 2-channel devices
  _addDebugMessage('🔧 Applying 2-channel specific configuration');
  
  // SetOption73 1 - Detach buttons from relays and send multi-press and hold MQTT messages
  await _publishMessage('cmnd/${device.tasmotaTopicBase}/SetOption73', '1');
  
  // ButtonTopic - Set button topic to device topic for proper status reporting
  await _publishMessage('cmnd/${device.tasmotaTopicBase}/ButtonTopic', device.tasmotaTopicBase!);
}
```

**Why 2-Channel Devices Need Special Configuration**:
- **SetOption73 1**: Detaches buttons from relays and enables proper MQTT button messages
- **ButtonTopic**: Ensures button presses send messages to the correct topic
- **Enhanced Status Reporting**: Ensures physical switch operations send `stat/` messages

## Expected Results

### **✅ Dynamic Topic Detection**

**Debug Logs Should Show**:
```
🔍 Extracted MQTT topic from device: hbot_8857CC
📋 Full status response: {Status: {Topic: hbot_8857CC, Power: 00000000, ...}}
📊 Power field length indicates 8 channels
✅ Detected 8 channels from Status.Power field
```

**For 2-Channel Device**:
```
🔍 Extracted MQTT topic from device: hbot_123456
📋 Full status response: {Status: {Topic: hbot_123456, Power: 00, ...}}
📊 Power field length indicates 2 channels
✅ Detected 2 channels from Status.Power field
🔧 Applying 2-channel specific configuration
```

### **✅ Accurate Channel Detection**

**Power Field Analysis**:
- `"00000000"` → 8 channels
- `"0000"` → 4 channels  
- `"00"` → 2 channels
- `"0"` → 1 channel

### **✅ 2-Channel Status Reporting**

**Physical Switch Operations on 2-Channel Device**:
```
📨 Received: stat/hbot_123456/POWER1 = ON
✅ Exact topic match found: Hbot-2ch for topic: stat/hbot_123456/POWER1
Updated device state: POWER1 = ON
Notified UI of state change for device: [2ch-device-id]
```

## Testing Instructions

### **1. Topic Detection Test**

1. **Provision a new device** (delete and re-add existing device)
2. **Check debug logs** for topic extraction:
   ```
   🔍 Extracted MQTT topic from device: [actual-topic]
   📋 Full status response: [full-json]
   ```
3. **Verify topic matches** what device actually uses
4. **Compare with manual status command**: `http://[device-ip]/cm?cmnd=status`

### **2. Channel Detection Test**

1. **Check Power field analysis**:
   ```
   📊 Power field length indicates [X] channels
   ✅ Detected [X] channels from Status.Power field
   ```
2. **Verify channel count** matches device capabilities
3. **Test both 2-channel and 8-channel devices**

### **3. 2-Channel Status Reporting Test**

1. **Add 2-channel device** to home
2. **Check for 2-channel specific configuration**:
   ```
   🔧 Applying 2-channel specific configuration
   ✅ Tasmota configuration completed for: [device-name]
   ```
3. **Test physical switches** on 2-channel device
4. **Verify `stat/` messages** are received for button presses

### **4. Multi-Device Test**

1. **Add both 2-channel and 8-channel devices** to same home
2. **Verify unique topics** are detected for each device
3. **Test physical switches** on both devices
4. **Confirm no topic conflicts** or message routing issues

## Troubleshooting

### **If Topic Detection Fails**

1. **Check device connectivity**: Ensure device is accessible at `192.168.4.1`
2. **Verify status command**: Manually test `http://[device-ip]/cm?cmnd=status`
3. **Check response format**: Ensure `Status.Topic` field exists
4. **Fallback behavior**: Should generate topic from MAC if detection fails

### **If 2-Channel Status Reporting Doesn't Work**

1. **Verify 2-channel configuration** was applied:
   ```
   🔧 Applying 2-channel specific configuration
   ```
2. **Check SetOption73**: Should be set to 1 for 2-channel devices
3. **Verify ButtonTopic**: Should match device topic base
4. **Manual configuration**: Can set via device web interface if needed

### **If Channel Detection Is Wrong**

1. **Check Power field**: Should match actual channel count
2. **Verify FriendlyName array**: Should have correct number of entries
3. **Manual verification**: Check device web interface for actual channel count
4. **Fallback detection**: Uses multiple methods if Power field fails

## Benefits

### **1. Accurate Topic Detection**
- ✅ **Dynamic extraction**: Gets actual topic from device
- ✅ **No hardcoding**: Adapts to any device configuration
- ✅ **Reliable fallback**: MAC-based generation if detection fails

### **2. Precise Channel Detection**
- ✅ **Power field analysis**: Most accurate method
- ✅ **Multiple fallbacks**: Ensures detection always works
- ✅ **Validation**: Normalizes to supported channel counts (2, 4, 8)

### **3. Device-Specific Configuration**
- ✅ **2-channel optimization**: Special settings for 2-channel devices
- ✅ **Status reporting**: Ensures physical switches work correctly
- ✅ **Scalable approach**: Easy to add configuration for other device types

## Conclusion

The dynamic MQTT topic detection fix ensures that:

1. **✅ Accurate Topic Detection**: Uses actual device topic instead of generated ones
2. **✅ Precise Channel Detection**: Analyzes Power field for exact channel count
3. **✅ 2-Channel Device Support**: Special configuration for proper status reporting
4. **✅ Multi-Device Compatibility**: Works with any number and type of devices
5. **✅ Robust Fallbacks**: Multiple detection methods ensure reliability

This resolves the issue where 2-channel devices weren't sending status updates for physical switch operations, while maintaining compatibility with 8-channel devices and supporting mixed device environments. 🎉
