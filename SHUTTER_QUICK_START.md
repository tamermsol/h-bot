# Shutter Device Quick Start Guide

## 🎯 Summary

Your hbot system now has **complete support for Tasmota shutter devices** with a beautiful UI featuring:
- 🎚️ **Position Slider** (0-100%)
- 🔘 **Three Control Buttons** (Close, Stop, Open)
- 📊 **Real-time Position Display**
- 🔌 **Connection Status Indicator**

## ✅ What's Been Added

### 1. MQTT Commands (Tasmota Protocol)
```dart
// lib/models/tasmota_device_info.dart
TasmotaCommand.shutterOpen(topicBase, shutterIndex)
TasmotaCommand.shutterClose(topicBase, shutterIndex)
TasmotaCommand.shutterStop(topicBase, shutterIndex)
TasmotaCommand.shutterPosition(topicBase, shutterIndex, position)
```

### 2. Service Layer Methods
```dart
// lib/services/mqtt_device_manager.dart
await mqttManager.openShutter(deviceId, 1);
await mqttManager.closeShutter(deviceId, 1);
await mqttManager.stopShutter(deviceId, 1);
await mqttManager.setShutterPosition(deviceId, 1, 50);
int? position = mqttManager.getShutterPosition(deviceId, 1);
```

### 3. UI Widget
```dart
// lib/widgets/shutter_control_widget.dart
ShutterControlWidget(
  device: device,
  mqttManager: mqttManager,
  shutterIndex: 1,
)
```

### 4. Automatic Integration
The system automatically shows shutter controls when `device.deviceType == DeviceType.shutter`

## 🚀 How to Add a Shutter Device

### Step 1: Configure Your Tasmota Device

Connect to your Tasmota device console and run:

```bash
# Enable shutter mode
Backlog SetOption80 1; ShutterRelay1 1

# Set timing (adjust to your shutter)
ShutterOpenDuration1 10
ShutterCloseDuration1 10

# Enable position reporting
ShutterReporting 1
```

### Step 2: Provision in App

1. **Open hbot app** → Tap "Add Device"
2. **Connect to device** → Follow Wi-Fi setup
3. **Name your device** → Use "shutter" or "blind" in the name
   - ✅ "Living Room Shutter"
   - ✅ "Bedroom Blind"
   - ✅ "Window Shutter"
4. **Complete setup** → Device will auto-detect as shutter type

### Step 3: Control Your Shutter

The app will automatically show the shutter control interface:

```
┌─────────────────────────────────────┐
│  ● Connected                        │
├─────────────────────────────────────┤
│                                     │
│   ┌─────┐    ┌─────┐    ┌─────┐   │
│   │  ↓  │    │ ║║  │    │  ↑  │   │
│   │Close│    │Stop │    │Open │   │
│   └─────┘    └─────┘    └─────┘   │
│                                     │
├─────────────────────────────────────┤
│              50%                    │
│   Close ━━━━━●━━━━━ Open          │
└─────────────────────────────────────┘
```

**Controls:**
- **Close Button** → Fully closes shutter (0%)
- **Stop Button** → Stops movement immediately
- **Open Button** → Fully opens shutter (100%)
- **Slider** → Drag to any position (0-100%)

## 📡 MQTT Topics Used

### Commands (App → Device)
```
cmnd/hbot_XXXXXX/ShutterOpen1       → Opens shutter
cmnd/hbot_XXXXXX/ShutterClose1      → Closes shutter
cmnd/hbot_XXXXXX/ShutterStop1       → Stops shutter
cmnd/hbot_XXXXXX/ShutterPosition1   → Sets position (0-100)
```

### Status (Device → App)
```
stat/hbot_XXXXXX/RESULT             → {"Shutter1":{"Position":50}}
tele/hbot_XXXXXX/STATE              → Periodic updates
```

## 🔧 Tasmota Configuration Details

### Basic Setup
```bash
# Step 1: Enable shutter mode
SetOption80 1

# Step 2: Configure relays as shutter
ShutterRelay1 1    # Uses Relay1 (UP) and Relay2 (DOWN)

# Step 3: Calibrate timing
ShutterOpenDuration1 10    # Time to fully open (seconds)
ShutterCloseDuration1 10   # Time to fully close (seconds)
```

### Calibration Process
```bash
# 1. Move to fully closed position
ShutterSetClose1

# 2. Move to fully open position manually, then:
ShutterSetOpen1

# 3. Test position accuracy
ShutterPosition1 50    # Should move to 50%
```

### Advanced Options
```bash
# Set shutter mode
ShutterMode1 0         # 0=normal, 1=venetian blind

# Enable position reporting
ShutterReporting 1     # Report position changes

# Set half-open position
ShutterSetHalfOpen1 50

# Invert direction (if needed)
ShutterInvert1 1
```

## 🎨 UI Design Features

### Button Styles
- **Close Button**: Gray with down arrow icon
- **Stop Button**: Blue/highlighted with pause icon (center)
- **Open Button**: Gray with up arrow icon

### Slider
- **Range**: 0% (closed) to 100% (open)
- **Color**: Blue active track
- **Labels**: "Close" on left, "Open" on right
- **Display**: Large percentage number above slider

### Status Indicators
- **Connection**: Green dot = connected, Red dot = disconnected
- **Moving**: Spinner appears when shutter is in motion
- **Position**: Real-time percentage display

## 📝 Code Examples

### Using in Your Code

```dart
import 'package:your_app/widgets/shutter_control_widget.dart';
import 'package:your_app/services/mqtt_device_manager.dart';

// In your widget
final mqttManager = MqttDeviceManager();

// Show shutter control
ShutterControlWidget(
  device: myShutterDevice,
  mqttManager: mqttManager,
  shutterIndex: 1,
)

// Or control programmatically
await mqttManager.openShutter(deviceId, 1);
await mqttManager.setShutterPosition(deviceId, 1, 75);
int? currentPos = mqttManager.getShutterPosition(deviceId, 1);
```

### Manual MQTT Testing

```bash
# Using mosquitto_pub
BROKER="y3ae1177.ala.eu-central-1.emqxsl.com"
PORT=8883
TOPIC_BASE="hbot_XXXXXX"

# Open shutter
mosquitto_pub -h $BROKER -p $PORT \
  -u admin -P 'P@ssword1' \
  --cafile ca.crt \
  -t "cmnd/$TOPIC_BASE/ShutterOpen1" -m ""

# Set to 50%
mosquitto_pub -h $BROKER -p $PORT \
  -u admin -P 'P@ssword1' \
  --cafile ca.crt \
  -t "cmnd/$TOPIC_BASE/ShutterPosition1" -m "50"

# Subscribe to status
mosquitto_sub -h $BROKER -p $PORT \
  -u admin -P 'P@ssword1' \
  --cafile ca.crt \
  -t "stat/$TOPIC_BASE/#" -t "tele/$TOPIC_BASE/#"
```

## 🐛 Troubleshooting

### Shutter Not Moving

**Check:**
1. ✅ Tasmota console: `SetOption80` should return `1`
2. ✅ Relays configured: `ShutterRelay1` should show relay numbers
3. ✅ MQTT connected: Green dot in app
4. ✅ Topic base correct: Check device settings

**Fix:**
```bash
# Reconfigure shutter
Backlog SetOption80 1; ShutterRelay1 1; Restart 1
```

### Position Not Updating

**Check:**
1. ✅ Position reporting enabled: `ShutterReporting 1`
2. ✅ Calibration done: Run `ShutterSetClose1` and `ShutterSetOpen1`
3. ✅ MQTT subscriptions active: Check debug logs

**Fix:**
```bash
# Enable reporting and recalibrate
Backlog ShutterReporting 1; ShutterSetClose1
# Move to open position, then:
ShutterSetOpen1
```

### Wrong Device Type

**If device shows as "relay" instead of "shutter":**

1. **Option 1**: Rename device to include "shutter" or "blind"
2. **Option 2**: Delete and re-provision with correct name
3. **Option 3**: Update database directly (advanced)

## 📊 Database Schema

Shutter devices use the same schema as other devices:

```sql
-- Device record
device_type: 'shutter'
channels: 1 (or 2 for dual shutters)
meta_json: {
  "shutter_index": 1,
  "calibrated": true,
  "open_duration": 10,
  "close_duration": 10
}
```

## 🔄 State Management

### Device State Structure
```dart
{
  "Shutter1": 50,              // Position 0-100
  "ShutterDirection1": 1,      // -1=closing, 0=stopped, 1=opening
  "optimistic": false,         // Optimistic update flag
  "timestamp": "2025-01-06T..."
}
```

### State Flow
```
User Action
  ↓
Widget State (optimistic)
  ↓
MQTT Command
  ↓
Tasmota Device
  ↓
MQTT Response
  ↓
Widget State (confirmed)
```

## 📚 Additional Resources

- **Tasmota Shutter Docs**: https://tasmota.github.io/docs/Blinds-and-Shutters/
- **MQTT Protocol**: https://tasmota.github.io/docs/MQTT/
- **hbot Documentation**: See `SHUTTER_DEVICE_IMPLEMENTATION.md`

## ✨ Summary

You now have **complete shutter device support** in your hbot system:

✅ **MQTT Commands** - All Tasmota shutter commands implemented
✅ **Service Layer** - Full integration with MQTT services
✅ **UI Widget** - Beautiful control interface with slider + buttons
✅ **Auto-Detection** - Automatic device type detection during provisioning
✅ **Real-time Updates** - Live position tracking via MQTT
✅ **Error Handling** - Robust error handling and user feedback

**Just provision a Tasmota shutter device and start controlling it!** 🎉

