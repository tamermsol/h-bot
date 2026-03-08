# Device Controls Working Fix

## Issue
The control buttons on device cards (shutter up/down/stop buttons and light switches) were not working when clicked directly on the device card in the room devices view.

## Root Cause
The `_initializeMqtt()` method was only listening for connection state changes but wasn't checking the current connection state when the screen loaded. Since the MQTT connection was already established by the dashboard/home screen, the DevicesScreen never received the "connected" event and `_mqttConnected` remained `false`.

When `_mqttConnected` is `false`, all control buttons are disabled:
```dart
onPressed: isControllable && _mqttConnected && isOnline
    ? () => _controlShutter(device, 'close')
    : null,  // Button disabled!
```

## Solution

Updated `_initializeMqtt()` to check the current connection state immediately when the screen loads:

```dart
Future<void> _initializeMqtt() async {
  // Check current connection state (NEW)
  final currentState = _mqttManager.mqttService.connectionState;
  if (mounted) {
    setState(() {
      _mqttConnected = currentState == MqttConnectionState.connected;
    });
  }

  // Listen to MQTT connection state changes (EXISTING)
  _mqttManager.connectionStateStream.listen((state) {
    if (mounted) {
      setState(() {
        _mqttConnected = state == MqttConnectionState.connected;
      });
    }
  });
}
```

## How It Works Now

1. **Screen Opens**: DevicesScreen calls `_initializeMqtt()`
2. **Check Current State**: Immediately checks if MQTT is already connected
3. **Update UI**: Sets `_mqttConnected = true` if already connected
4. **Enable Controls**: All buttons become enabled because `_mqttConnected && isOnline` is now true
5. **Listen for Changes**: Continues to listen for future connection state changes

## Control Button Behavior

### Shutter Controls
- **Close Button**: Works when position > 0%, dims at 0%
- **Stop Button**: Always works when online
- **Open Button**: Works when position < 100%, dims at 100%

### Light Switch
- **Switch**: Toggles device on/off when online
- **Visual Feedback**: Switch animates and updates immediately

## Files Modified

- `lib/screens/devices_screen.dart`
  - Updated `_initializeMqtt()` to check current connection state

## Testing Checklist

- [x] Shutter close button works (when position > 0%)
- [x] Shutter stop button works
- [x] Shutter open button works (when position < 100%)
- [x] Light switch works (toggles on/off)
- [x] Buttons disabled when device offline
- [x] Buttons work without opening device detail screen
- [x] Visual feedback when buttons pressed
- [x] MQTT connection state tracked correctly

## Result

All control buttons on device cards now work correctly without having to open the device detail screen. Users can control shutters and lights directly from the room devices view.
