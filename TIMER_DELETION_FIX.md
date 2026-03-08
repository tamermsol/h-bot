# Timer Deletion and Slot Recalculation Fix

## Issues Fixed

### Issue 1: Stale Slot Count After Deletion
**Problem**: After deleting timers, the app bar still showed old slot count (e.g., "9/16 slots used • 0 timers")

**Root Cause**: `_calculateOccupiedIndices()` was not being called after timer deletion, so the occupied slots set remained stale.

**Fix**: Added `_calculateOccupiedIndices()` call immediately after removing timer from list:

```dart
setState(() {
  _timers.removeWhere((t) => t.index == timer.index);
  _calculateOccupiedIndices(); // ✅ Recalculate immediately
});
```

### Issue 2: False "Limit Reached" Dialog
**Problem**: Dialog showed "limit reached" even when slots were available (e.g., 9/16 slots used)

**Root Cause**: The `_addTimer()` method was checking stale `_occupiedIndices` data without recalculating first.

**Fix**: Added recalculation at the start of `_addTimer()`:

```dart
Future<void> _addTimer() async {
  final maxChannels = widget.device.channels ?? 1;
  
  // ✅ Recalculate occupied indices to ensure we have fresh data
  _calculateOccupiedIndices();
  
  // Now check availability with fresh data
  final nextIndex = _getNextAvailableIndex(slotsNeeded: maxChannels);
  // ...
}
```

### Issue 3: Dialog UI Overlay Issue
**Problem**: Dialog content had visual glitches with overlapping text elements

**Root Cause**: Long text in dialog content without proper layout structure

**Fix**: Wrapped dialog content in `SingleChildScrollView` with proper `Column` structure:

```dart
content: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'HBOT devices support a maximum of 16 local timer slots.',
        style: TextStyle(fontSize: 14),
      ),
      const SizedBox(height: 12),
      Text(
        'Currently occupied: ${_occupiedIndices.length}/16 slots',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '(Note: "All Channels" timers use $maxChannels slots)',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary.withValues(alpha: 0.8),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'To add more timers, please delete an existing timer or use Scene Control for advanced automation.',
        style: TextStyle(fontSize: 14),
      ),
    ],
  ),
),
```

### Issue 4: Slot Count Not Updated After Edit/Toggle
**Problem**: Editing or toggling timers didn't update slot count if channel selection changed

**Fix**: Added `_calculateOccupiedIndices()` to edit and toggle methods:

```dart
// In _editTimer()
setState(() {
  final index = _timers.indexWhere((t) => t.index == result.index);
  if (index != -1) {
    _timers[index] = result;
  }
  _calculateOccupiedIndices(); // ✅ Recalculate after edit
});

// In _toggleTimer()
setState(() {
  final index = _timers.indexWhere((t) => t.index == timer.index);
  if (index != -1) {
    _timers[index] = updatedTimer;
  }
  _calculateOccupiedIndices(); // ✅ Recalculate after toggle
});
```

## Changes Made

### 1. `_addTimer()` Method
- Added `_calculateOccupiedIndices()` at the start to ensure fresh data
- Improved dialog layout with `SingleChildScrollView` and proper spacing
- Fixed icon size and text wrapping issues

### 2. `_deleteTimer()` Method
- Added `_calculateOccupiedIndices()` immediately after removing timer
- Ensured slot count updates before showing success message

### 3. `_editTimer()` Method
- Added `_calculateOccupiedIndices()` after updating timer
- Handles case where user changes from single-channel to all-channels

### 4. `_toggleTimer()` Method
- Added `_calculateOccupiedIndices()` after toggling
- Ensures slot tracking stays accurate

## Testing Scenarios

### Scenario 1: Delete All Timers
```
Before: 9/16 slots used • 1 timer
Action: Delete the timer
After: 0/16 slots used • 0 timers ✅
Result: Can now add new timers ✅
```

### Scenario 2: Delete and Add
```
1. Have 2 "All Channels" timers (16/16 slots on 8ch device)
2. Delete one timer
3. Slot count updates to 8/16 ✅
4. Can now add new timer ✅
```

### Scenario 3: Edit Timer Channel
```
1. Have timer on "All Channels" (8 slots)
2. Edit to "Channel 1" (1 slot)
3. Slot count updates from 8/16 to 1/16 ✅
4. Can now add more timers ✅
```

### Scenario 4: Toggle Timer
```
1. Toggle timer on/off
2. Slot count remains accurate ✅
3. No stale data issues ✅
```

## UI Improvements

### Dialog Layout
**Before**:
- Text overlapping
- Poor spacing
- Hard to read

**After**:
- Clean layout with proper spacing
- Scrollable content
- Clear hierarchy
- Proper text sizing

### Feedback Messages
**Deletion**:
```
"Timer deleted and disabled on device
Freed 8 slots (0/16 used)"
```
Shows:
- Action completed
- Slots freed
- Current usage

## Benefits

1. ✅ **Accurate Slot Tracking**: Always shows correct slot count
2. ✅ **No False Limits**: Only shows limit dialog when truly at capacity
3. ✅ **Clean UI**: Dialog displays properly without overlaps
4. ✅ **Immediate Updates**: Slot count updates instantly after any change
5. ✅ **Reliable State**: No stale data causing incorrect behavior

## Technical Details

### When `_calculateOccupiedIndices()` is Called

1. **On Load**: `_loadTimers()` → Calculates initial state
2. **On Add**: `_addTimer()` → Before checking availability, after adding
3. **On Edit**: `_editTimer()` → After updating timer
4. **On Toggle**: `_toggleTimer()` → After toggling state
5. **On Delete**: `_deleteTimer()` → After removing timer

### Why This Works

The key insight is that `_occupiedIndices` is a **derived state** - it's calculated from `_timers`. Every time `_timers` changes, we must recalculate `_occupiedIndices` to keep them in sync.

**Pattern**:
```dart
setState(() {
  // 1. Modify _timers
  _timers.add(newTimer);
  
  // 2. Immediately recalculate derived state
  _calculateOccupiedIndices();
});
```

This ensures the UI always displays accurate information and prevents logic errors from stale data.

## Conclusion

All timer deletion and slot tracking issues are now resolved. The app correctly:
- Updates slot count after any timer operation
- Shows limit dialog only when truly at capacity
- Displays dialogs with clean, readable layout
- Maintains accurate state throughout the app lifecycle
