# Timer Conflict Management & Limits

## Overview
Enhanced timer management system with automatic conflict resolution, 16-timer limit enforcement, and proper device synchronization.

## Key Features

### 1. Automatic Conflict Resolution
When creating a new timer, the system automatically detects and disables conflicting timers to prevent multiple timers from triggering simultaneously.

**Conflict Detection Logic:**
- **Channel Overlap**: Timers affecting the same channel or "All Channels"
- **Time Proximity**: Timers within 1 minute of each other
- **Day Overlap**: Timers scheduled on the same days
- **Mode Matching**: Only same-mode timers conflict (Time vs Sunrise/Sunset)

**Example:**
```
Existing Timer: CH1, 07:00, Mon-Fri, Turn ON
New Timer:      CH1, 07:01, Mon-Fri, Turn OFF
→ System disables the existing timer automatically
```

### 2. 16 Timer Limit Enforcement
HBOT devices (Tasmota-compatible) support a maximum of 16 local timers. The app enforces this limit:

**UI Indicators:**
- Timer count shown in app bar: "5/16 timers used"
- Warning color when limit reached (orange)
- Add button hidden when at limit
- Dialog explaining limit and suggesting Scene Control

**Limit Dialog Message:**
```
"HBOT devices support a maximum of 16 local timers.
You have reached this limit.

To add more timers, please delete an existing timer 
or use Scene Control for advanced automation."
```

### 3. Device Synchronization

#### Timer Deletion
When deleting a timer:
1. Timer is disabled on the device first
2. Then removed from local storage
3. Confirmation message shows both actions completed

**MQTT Command Sent:**
```
Timer2 {"Enable":0,"Mode":0,"Time":"02:40","Window":0,"Days":"1111111","Repeat":0,"Output":8,"Action":0}
```

#### Time Synchronization
Before sending any timer command:
1. Device time synced with phone time
2. Timezone offset applied
3. ISO 8601 timestamp sent to device

**Commands:**
```
Timezone +2
Time 2024-12-20T14:42:49
```

## Implementation Details

### Conflict Detection Algorithm

```dart
Future<void> _cancelConflictingTimers(DeviceTimer newTimer) async {
  final conflictingTimers = _timers.where((existingTimer) {
    // Skip same timer (editing)
    if (existingTimer.index == newTimer.index) return false;

    // Check channel overlap
    final channelsOverlap = 
        (newTimer.output == 0 || existingTimer.output == 0) ||
        (newTimer.output == existingTimer.output);
    
    if (!channelsOverlap) return false;

    // Check time proximity (within 1 minute)
    if (newTimer.mode == TimerMode.time && existingTimer.mode == TimerMode.time) {
      final newMinutes = newTimer.time.hour * 60 + newTimer.time.minute;
      final existingMinutes = existingTimer.time.hour * 60 + existingTimer.time.minute;
      final timeDiff = (newMinutes - existingMinutes).abs();
      
      if (timeDiff > 1) return false;
    }

    // Check day overlap
    for (int i = 0; i < 7; i++) {
      if (newTimer.days[i] && existingTimer.days[i]) {
        return true;
      }
    }

    return false;
  }).toList();

  // Disable conflicting timers
  for (final conflictingTimer in conflictingTimers) {
    final disabledTimer = conflictingTimer.copyWith(enabled: false);
    await _sendTimerToDevice(disabledTimer);
    // Update local list...
  }
}
```

### Timer Limit Check

```dart
Future<void> _addTimer() async {
  // Check 16 timer limit
  if (_timers.length >= 16) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            Text('Timer Limit Reached'),
          ],
        ),
        content: const Text(
          'Tasmota devices support a maximum of 16 local timers...'
        ),
      ),
    );
    return;
  }

  // Proceed with timer creation...
}
```

### Deletion with Device Sync

```dart
Future<void> _deleteTimer(DeviceTimer timer) async {
  if (confirmed == true) {
    // 1. Disable on device first
    final disabledTimer = timer.copyWith(enabled: false);
    await _sendTimerToDevice(disabledTimer);
    
    // 2. Remove from local storage
    setState(() {
      _timers.removeWhere((t) => t.index == timer.index);
    });
    await _saveTimers();

    // 3. Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Timer ${timer.index} deleted and disabled on device'),
      ),
    );
  }
}
```

## User Experience

### Visual Feedback

1. **Timer Count Display**
   - Always visible in app bar
   - Changes color when approaching limit
   - Format: "X/16 timers used"

2. **Conflict Resolution**
   - Orange snackbar: "Disabled N conflicting timer(s)"
   - Duration: 2 seconds
   - Non-intrusive notification

3. **Limit Warning**
   - Full-screen dialog
   - Clear explanation
   - Actionable suggestions

4. **Deletion Confirmation**
   - Green snackbar: "Timer X deleted and disabled on device"
   - Confirms both local and device actions

### Edge Cases Handled

1. **Multiple Conflicts**: All conflicting timers disabled
2. **Editing Timer**: Doesn't conflict with itself
3. **All Channels**: Conflicts with any single-channel timer at same time
4. **Different Modes**: Sunrise/Sunset don't conflict with Time mode
5. **Non-overlapping Days**: No conflict if days don't overlap

## Testing Scenarios

### Scenario 1: Conflict Detection
```
1. Create Timer1: CH1, 07:00, Mon-Fri, ON
2. Create Timer2: CH1, 07:01, Mon-Fri, OFF
→ Timer1 automatically disabled
→ Orange notification shown
```

### Scenario 2: Limit Enforcement
```
1. Create 16 timers
2. Try to add 17th timer
→ Warning dialog appears
→ Add button hidden
→ Timer count shows "16/16" in orange
```

### Scenario 3: Deletion Sync
```
1. Delete Timer5
→ Device receives: Timer5 {"Enable":0,...}
→ Timer removed from app
→ Green confirmation shown
```

### Scenario 4: Time Sync
```
1. Add any timer
→ Device time synced first
→ Timezone command sent
→ Time command sent
→ Timer command sent
```

## Benefits

1. **Prevents Timer Conflicts**: No more unexpected behavior from overlapping timers
2. **Enforces Device Limits**: Users can't exceed the 16-timer limit on HBOT devices
3. **Proper Cleanup**: Deleted timers are disabled on device, not just removed from app
4. **Time Accuracy**: Device time always synced with phone before timer operations
5. **Clear Feedback**: Users always know timer count and limit status

## Future Enhancements

1. **Scene Control Integration**: Suggest specific scenes when limit reached
2. **Timer Groups**: Manage related timers together
3. **Conflict Preview**: Show which timers will be disabled before confirming
4. **Bulk Operations**: Enable/disable multiple timers at once
5. **Timer Templates**: Save and reuse common timer configurations
