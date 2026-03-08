# Timer All Channels and Time Sync Fix

## Issues Fixed

### 1. Timer Only Sending to Channel 1
**Problem**: When setting a timer for "All Channels" (output=0), the timer command was only being sent to channel 1.

**Root Cause**: Tasmota doesn't support `"Output":0` to control all channels with a single timer. Each channel needs its own timer command.

**Solution**: 
- Modified `DeviceTimer.toTasmotaCommands()` to return a list of commands
- When `output=0` (all channels), it now creates separate timer commands for each channel
- Each channel gets its own timer index to avoid conflicts (e.g., Timer1 for CH1, Timer2 for CH2, etc.)

**Example**:
```dart
// Before: Single command with Output:0
Timer1 {"Enable":1,"Mode":0,"Time":"13:15","Window":0,"Days":"1111111","Repeat":1,"Output":0,"Action":1}

// After: Multiple commands, one per channel
Timer1 {"Enable":1,"Mode":0,"Time":"13:15","Window":0,"Days":"1111111","Repeat":1,"Output":1,"Action":1}
Timer2 {"Enable":1,"Mode":0,"Time":"13:15","Window":0,"Days":"1111111","Repeat":1,"Output":2,"Action":1}
Timer3 {"Enable":1,"Mode":0,"Time":"13:15","Window":0,"Days":"1111111","Repeat":1,"Output":3,"Action":1}
Timer4 {"Enable":1,"Mode":0,"Time":"13:15","Window":0,"Days":"1111111","Repeat":1,"Output":4,"Action":1}
```

### 2. Device Time Not Synced with Phone Time
**Problem**: The device time was different from the phone time, causing timers to trigger at incorrect times.

**Root Cause**: No time synchronization was happening between the mobile app and the Tasmota device.

**Solution**:
- Added `_syncDeviceTime()` method that runs before sending timer commands
- Syncs timezone offset using `Timezone` command
- Sets actual device time using `Time` command with ISO8601 format
- Added visual indicator (loading spinner) in app bar during sync

**Commands Sent**:
```
Timezone +2          // Sets timezone offset (example: UTC+2)
Time 2025-12-20T13:11:27  // Sets actual device time
```

## Files Modified

### lib/models/device_timer.dart
- Added `toTasmotaCommands(int maxChannels)` method that returns `List<String>`
- Handles "all channels" case by creating multiple timer commands
- Kept legacy `toTasmotaCommand()` for backward compatibility (deprecated)

### lib/screens/device_timers_screen.dart
- Added `_isSyncingTime` state variable
- Added `_syncDeviceTime()` method to sync device time with phone
- Modified `_sendTimerToDevice()` to:
  - Call `_syncDeviceTime()` first
  - Use `toTasmotaCommands()` to get list of commands
  - Send each command with small delay between them
  - Show appropriate success message for all channels vs single channel
- Updated UI to show loading indicator during time sync

## Testing

To verify the fixes:

1. **All Channels Timer**:
   - Create a timer with "All Channels" selected
   - Check MQTT console - you should see multiple Timer commands (one per channel)
   - Verify all channels turn on/off at the scheduled time

2. **Time Synchronization**:
   - Check device time: Send `Time` command via MQTT console
   - Compare with phone time
   - Create a timer and verify it triggers at the correct phone time
   - Check logs for time sync messages: `⏰ Synced device timezone to UTC+X`

## MQTT Console Output

You should now see:
```
⏰ Synced device timezone to UTC+2
⏰ Synced device time to: 2025-12-20T13:11:27
📤 Sending 4 timer command(s)
📤 Command: Timer1 {"Enable":1,"Mode":0,"Time":"13:15",...,"Output":1,...}
📤 Command: Timer2 {"Enable":1,"Mode":0,"Time":"13:15",...,"Output":2,...}
📤 Command: Timer3 {"Enable":1,"Mode":0,"Time":"13:15",...,"Output":3,...}
📤 Command: Timer4 {"Enable":1,"Mode":0,"Time":"13:15",...,"Output":4,...}
✅ Timer command(s) sent successfully
```

## Notes

- Time sync happens automatically before each timer is saved
- Small delays (100ms) between commands prevent overwhelming the device
- Time sync failures don't block timer creation (graceful degradation)
- UI shows loading indicator during time sync for better UX
