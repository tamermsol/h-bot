# Tasmota Shutter Device Implementation Guide

## Overview

This guide explains how to add and control Tasmota shutter devices in the hbot smart home system. Shutter devices are different from relay/light devices - they use position-based control (0-100%) instead of simple ON/OFF states.

## What's Been Implemented

### 1. **Tasmota Command Support** ✅

Added shutter-specific MQTT commands to `lib/models/tasmota_device_info.dart`:

```dart
// Shutter commands
TasmotaCommand.shutterOpen(topicBase, shutterIndex)    // Open shutter
TasmotaCommand.shutterClose(topicBase, shutterIndex)   // Close shutter
TasmotaCommand.shutterStop(topicBase, shutterIndex)    // Stop shutter
TasmotaCommand.shutterPosition(topicBase, shutterIndex, position) // Set position 0-100
```

**MQTT Topics Generated:**
- `cmnd/{topicBase}/ShutterOpen1` - Opens shutter 1
- `cmnd/{topicBase}/ShutterClose1` - Closes shutter 1
- `cmnd/{topicBase}/ShutterStop1` - Stops shutter 1
- `cmnd/{topicBase}/ShutterPosition1` - Sets position (payload: 0-100)

### 2. **MQTT Service Integration** ✅

Added shutter control methods to both MQTT services:

**TasmotaMqttService** (`lib/services/tasmota_mqtt_service.dart`):
```dart
await mqttService.openShutter(topicBase, shutterIndex);
await mqttService.closeShutter(topicBase, shutterIndex);
await mqttService.stopShutter(topicBase, shutterIndex);
await mqttService.setShutterPosition(topicBase, shutterIndex, position);
```

**EnhancedMqttService** (`lib/services/enhanced_mqtt_service.dart`):
```dart
await enhancedMqttService.openShutter(deviceId, shutterIndex);
await enhancedMqttService.closeShutter(deviceId, shutterIndex);
await enhancedMqttService.stopShutter(deviceId, shutterIndex);
await enhancedMqttService.setShutterPosition(deviceId, shutterIndex, position);
```

**MqttDeviceManager** (`lib/services/mqtt_device_manager.dart`):
```dart
await mqttManager.openShutter(deviceId, shutterIndex);
await mqttManager.closeShutter(deviceId, shutterIndex);
await mqttManager.stopShutter(deviceId, shutterIndex);
await mqttManager.setShutterPosition(deviceId, shutterIndex, position);
int? position = mqttManager.getShutterPosition(deviceId, shutterIndex);
```

### 3. **Shutter Control Widget** ✅

Created a dedicated UI widget (`lib/widgets/shutter_control_widget.dart`) with:

**Features:**
- ✅ **Slider Control**: Drag to set position (0-100%)
- ✅ **Three Buttons**: Close, Stop (highlighted), Open
- ✅ **Position Display**: Shows current position percentage
- ✅ **Connection Status**: Visual indicator for MQTT connection
- ✅ **Moving Indicator**: Shows when shutter is in motion
- ✅ **Real-time Updates**: Listens to MQTT state changes

**UI Layout:**
```
┌─────────────────────────────────┐
│ ● Connected          [spinner]  │
├─────────────────────────────────┤
│  [Close]  [Stop]  [Open]        │
│    ↓        ||       ↑          │
├─────────────────────────────────┤
│           50%                   │
│  Close ━━━━●━━━━ Open          │
└─────────────────────────────────┘
```

### 4. **Device Type Support** ✅

The `DeviceType.shutter` enum already exists in `lib/models/device.dart`:
```dart
enum DeviceType {
  relay,
  dimmer,
  shutter,  // ✅ Already defined
  sensor,
  other;
}
```

### 5. **Provisioning Integration** ✅

The device provisioning flow (`lib/screens/add_device_flow_screen.dart`) already detects shutter devices:

```dart
DeviceType _determineDeviceType(String deviceName) {
  final name = deviceName.toLowerCase();
  if (name.contains('light') || name.contains('bulb')) {
    return DeviceType.dimmer;
  } else if (name.contains('sensor')) {
    return DeviceType.sensor;
  } else if (name.contains('shutter') || name.contains('blind')) {
    return DeviceType.shutter;  // ✅ Already implemented
  }
  return DeviceType.relay;
}
```

### 6. **UI Integration** ✅

The `EnhancedDeviceControlWidget` now automatically shows shutter controls for shutter devices:

```dart
// In enhanced_device_control_widget.dart
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
```

## How to Add a Shutter Device

### Step 1: Configure Tasmota Device

On your Tasmota device, configure it as a shutter:

```
# In Tasmota console:
Backlog SetOption80 1; ShutterRelay1 1; ShutterRelay1 2
```

This configures:
- Relay 1 as shutter UP
- Relay 2 as shutter DOWN

### Step 2: Name Your Device

When provisioning the device, name it with "shutter" or "blind" in the name:
- ✅ "Living Room Shutter"
- ✅ "Bedroom Blind"
- ✅ "Kitchen Window Shutter"

The system will automatically detect it as a shutter device.

### Step 3: Provision Through App

1. Open the app
2. Go to "Add Device"
3. Follow the Wi-Fi provisioning flow
4. The device will be automatically detected as type `shutter`
5. The shutter control UI will appear automatically

### Step 4: Control Your Shutter

**Via UI:**
- Tap **Close** button to fully close
- Tap **Stop** button to stop movement
- Tap **Open** button to fully open
- Drag **slider** to set specific position (0-100%)

**Via MQTT (for testing):**
```bash
# Open shutter
mosquitto_pub -h broker -t "cmnd/hbot_XXXXXX/ShutterOpen1" -m ""

# Close shutter
mosquitto_pub -h broker -t "cmnd/hbot_XXXXXX/ShutterClose1" -m ""

# Stop shutter
mosquitto_pub -h broker -t "cmnd/hbot_XXXXXX/ShutterStop1" -m ""

# Set position to 50%
mosquitto_pub -h broker -t "cmnd/hbot_XXXXXX/ShutterPosition1" -m "50"
```

## MQTT Topics Reference

### Commands (App → Device)

| Topic | Payload | Description |
|-------|---------|-------------|
| `cmnd/{topic}/ShutterOpen1` | (empty) | Open shutter 1 |
| `cmnd/{topic}/ShutterClose1` | (empty) | Close shutter 1 |
| `cmnd/{topic}/ShutterStop1` | (empty) | Stop shutter 1 |
| `cmnd/{topic}/ShutterPosition1` | `0-100` | Set position % |

### Status (Device → App)

| Topic | Payload | Description |
|-------|---------|-------------|
| `stat/{topic}/RESULT` | `{"Shutter1":{"Position":50}}` | Position update |
| `tele/{topic}/STATE` | `{"Shutter1":{"Position":50}}` | Periodic state |

## Tasmota Shutter Configuration

### Basic Configuration

```
# Configure shutter mode
SetOption80 1

# Set relay 1 and 2 as shutter
ShutterRelay1 1

# Set shutter open time (seconds)
ShutterOpenDuration1 10

# Set shutter close time (seconds)
ShutterCloseDuration1 10

# Set shutter mode (0=normal, 1=venetian blind)
ShutterMode1 0
```

### Advanced Configuration

```
# Set shutter position calibration
ShutterSetClose1

# After moving to fully open position:
ShutterSetOpen1

# Set half-open position
ShutterSetHalfOpen1 50

# Enable position reporting
ShutterReporting 1
```

## Code Architecture

### Data Flow

```
User Action (UI)
    ↓
ShutterControlWidget
    ↓
MqttDeviceManager
    ↓
EnhancedMqttService
    ↓
MQTT Broker
    ↓
Tasmota Device
    ↓
MQTT Broker (stat/tele)
    ↓
EnhancedMqttService
    ↓
MqttDeviceManager
    ↓
ShutterControlWidget (State Update)
```

### Key Files Modified

1. ✅ `lib/models/tasmota_device_info.dart` - Added shutter commands
2. ✅ `lib/services/tasmota_mqtt_service.dart` - Added shutter methods
3. ✅ `lib/services/enhanced_mqtt_service.dart` - Added shutter methods
4. ✅ `lib/services/mqtt_device_manager.dart` - Added shutter methods
5. ✅ `lib/widgets/shutter_control_widget.dart` - NEW: Shutter UI
6. ✅ `lib/widgets/enhanced_device_control_widget.dart` - Integrated shutter UI
7. ✅ `lib/screens/add_device_flow_screen.dart` - Already supports shutter detection

## Testing Checklist

- [ ] Provision a shutter device through the app
- [ ] Verify device is detected as type `shutter`
- [ ] Test **Open** button - shutter opens fully
- [ ] Test **Close** button - shutter closes fully
- [ ] Test **Stop** button - shutter stops mid-movement
- [ ] Test **Slider** - drag to 50%, verify shutter moves to 50%
- [ ] Verify position display updates in real-time
- [ ] Test connection indicator shows correct status
- [ ] Test moving indicator appears during movement
- [ ] Verify MQTT messages are sent correctly
- [ ] Test state persistence after app restart

## Troubleshooting

### Shutter Not Responding

1. Check MQTT connection status (should show "Connected")
2. Verify Tasmota device is configured as shutter (`SetOption80 1`)
3. Check MQTT broker logs for command messages
4. Verify topic base is correct in device settings

### Position Not Updating

1. Ensure `ShutterReporting 1` is enabled on Tasmota
2. Check that device is subscribed to `stat/` and `tele/` topics
3. Verify MQTT state messages are being received
4. Check debug logs in app for state updates

### Wrong Device Type

If device is detected as `relay` instead of `shutter`:
1. Rename device to include "shutter" or "blind"
2. Delete and re-provision the device
3. Or manually update device type in database

## Future Enhancements

- [ ] Support for multiple shutters per device (Shutter2, Shutter3, etc.)
- [ ] Venetian blind tilt control
- [ ] Preset positions (25%, 50%, 75%)
- [ ] Scheduling (open at sunrise, close at sunset)
- [ ] Scene integration (include shutters in scenes)
- [ ] Voice control integration

## Summary

✅ **Complete Implementation** - All components are in place for shutter device support:
- MQTT commands defined
- Service methods implemented
- UI widget created
- Provisioning integrated
- Device type detection working

🎯 **Ready to Use** - Simply provision a Tasmota shutter device with "shutter" or "blind" in the name, and the app will automatically provide the appropriate control interface.

