# Timer Slot Allocation System

## Overview
Intelligent timer slot allocation system that properly tracks and manages the 16 timer slots available on HBOT devices (Tasmota-compatible), accounting for "All Channels" timers that occupy multiple slots.

## Key Concept: Slots vs Timers

**Important Distinction:**
- **Timers**: User-created timer configurations (can be single-channel or all-channels)
- **Slots**: Physical timer indices on the device (1-16)

**Example:**
```
Device with 8 channels:
- Timer 1: "All Channels" at 07:00 → Occupies slots 1-8 (8 slots)
- Timer 2: "Channel 1" at 08:00 → Occupies slot 9 (1 slot)
- Timer 3: "All Channels" at 09:00 → Occupies slots 10-16 (7 slots, but needs 8!)
  ❌ Cannot fit! Only 7 slots remaining.
```

## Slot Allocation Algorithm

### 1. Calculate Occupied Indices
When loading timers, calculate which device slots are occupied:

```dart
void _calculateOccupiedIndices() {
  _occupiedIndices.clear();
  final maxChannels = widget.device.channels ?? 1;
  
  for (final timer in _timers) {
    if (timer.output == 0) {
      // All channels timer occupies multiple indices
      for (int ch = 0; ch < maxChannels; ch++) {
        _occupiedIndices.add(timer.index + ch);
      }
    } else {
      // Single channel timer occupies one index
      _occupiedIndices.add(timer.index);
    }
  }
  
  debugPrint('📊 Occupied timer indices: $_occupiedIndices (${_occupiedIndices.length}/16)');
}
```

### 2. Find Next Available Index
Find the first contiguous block of available slots:

```dart
int? _getNextAvailableIndex({required int slotsNeeded}) {
  // Find first contiguous block of available indices
  for (int startIdx = 1; startIdx <= 16; startIdx++) {
    bool canFit = true;
    
    // Check if we have enough contiguous slots
    for (int offset = 0; offset < slotsNeeded; offset++) {
      final checkIdx = startIdx + offset;
      if (checkIdx > 16 || _occupiedIndices.contains(checkIdx)) {
        canFit = false;
        break;
      }
    }
    
    if (canFit) {
      return startIdx;
    }
  }
  
  return null; // No available slots
}
```

### 3. Allocate Timer with Proper Index
When adding a timer:

```dart
Future<void> _addTimer() async {
  final maxChannels = widget.device.channels ?? 1;
  
  // Calculate next available index (worst case: all channels)
  final nextIndex = _getNextAvailableIndex(slotsNeeded: maxChannels);
  
  if (nextIndex == null) {
    // Show limit reached dialog
    return;
  }
  
  // User configures timer...
  final result = await Navigator.push(...);
  
  if (result != null) {
    // Calculate actual slots needed
    final slotsNeeded = result.output == 0 ? maxChannels : 1;
    
    // Verify we still have space
    final finalIndex = _getNextAvailableIndex(slotsNeeded: slotsNeeded);
    
    if (finalIndex == null) {
      // Not enough contiguous slots
      return;
    }
    
    // Update timer index to allocated index
    final finalTimer = result.copyWith(index: finalIndex);
    
    // Add timer and recalculate occupied indices
    _timers.add(finalTimer);
    _calculateOccupiedIndices();
  }
}
```

## Real-World Examples

### Example 1: 8-Channel Device

**Initial State:**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [ Empty - All 16 slots available                        ]
```

**Add Timer 1: All Channels at 07:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [Timer1 - 8 slots  ][  8 slots remaining              ]
Occupied: {1,2,3,4,5,6,7,8}
```

**Add Timer 2: Channel 3 at 08:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [Timer1 - 8 slots  ][T2][ 7 slots remaining          ]
Occupied: {1,2,3,4,5,6,7,8,9}
```

**Add Timer 3: All Channels at 09:00**
```
❌ CANNOT FIT!
Need: 8 contiguous slots
Available: Only 7 contiguous slots (10-16)

Dialog shown:
"Currently occupied: 9/16 slots
(Note: "All Channels" timers use 8 slots)
To add more timers, delete an existing timer or use Scene Control."
```

**Delete Timer 1 (frees slots 1-8)**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [ 8 slots free     ][T2][ 7 slots free              ]
Occupied: {9}

Message: "Freed 8 slots (1/16 used)"
```

**Now Add Timer 3: All Channels at 09:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [Timer3 - 8 slots  ][T2][ 7 slots free              ]
Occupied: {1,2,3,4,5,6,7,8,9}
✅ SUCCESS! Allocated to slots 1-8
```

### Example 2: 4-Channel Device

**Add Timer 1: All Channels at 07:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [T1-4ch][  12 slots remaining                         ]
Occupied: {1,2,3,4}
```

**Add Timer 2: All Channels at 08:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [T1-4ch][T2-4ch][  8 slots remaining                  ]
Occupied: {1,2,3,4,5,6,7,8}
```

**Add Timer 3: All Channels at 09:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [T1-4ch][T2-4ch][T3-4ch][  4 slots remaining          ]
Occupied: {1,2,3,4,5,6,7,8,9,10,11,12}
```

**Add Timer 4: All Channels at 10:00**
```
Slots: [1][2][3][4][5][6][7][8][9][10][11][12][13][14][15][16]
       [T1-4ch][T2-4ch][T3-4ch][T4-4ch]
Occupied: {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16}
✅ All 16 slots used! (4 timers × 4 channels each)
```

**Try to Add Timer 5:**
```
❌ CANNOT FIT!
Dialog: "Currently occupied: 16/16 slots"
```

## UI Feedback

### App Bar Display
```
"12/16 slots used • 3 timers"
```
- Shows actual slot usage (not just timer count)
- Turns orange when 16/16 slots occupied
- Shows both slots and timer count for clarity

### Timer Card Display
```
Timer 1: 07:00 AM
All Channels • Every day
Slots 1-8
```
- Shows which device slots this timer occupies
- Helps users understand slot allocation

### Deletion Feedback
```
"Timer deleted and disabled on device
Freed 8 slots (8/16 used)"
```
- Shows how many slots were freed
- Shows current slot usage after deletion

### Limit Dialog
```
"HBOT devices support a maximum of 16 local timer slots.

Currently occupied: 14/16 slots
(Note: "All Channels" timers use 8 slots)

To add more timers, please delete an existing timer 
or use Scene Control for advanced automation."
```
- Explains slot concept
- Shows current usage
- Provides actionable guidance

## Benefits

1. **Accurate Slot Tracking**: Properly accounts for multi-slot timers
2. **Optimal Allocation**: Finds first available contiguous block
3. **Clear Feedback**: Users understand slot vs timer distinction
4. **Prevents Errors**: Can't create timers that won't fit
5. **Smart Reuse**: Freed slots are immediately available

## Edge Cases Handled

1. **Fragmentation**: Finds first contiguous block, not just next index
2. **User Changes Selection**: Rechecks availability after user configures timer
3. **All Channels → Single Channel**: Adjusts slot requirement dynamically
4. **Deletion**: Recalculates occupied indices immediately
5. **Mixed Timers**: Handles combination of single-channel and all-channel timers

## Technical Details

### Data Structures
```dart
// Track occupied device slots (not timer count)
Set<int> _occupiedIndices = {};

// User-created timers (can occupy 1 or N slots each)
List<DeviceTimer> _timers = [];
```

### Key Methods
- `_calculateOccupiedIndices()`: Recalculate after any timer change
- `_getNextAvailableIndex(slotsNeeded)`: Find contiguous block
- `_addTimer()`: Allocate with proper index
- `_deleteTimer()`: Free slots and recalculate

### MQTT Commands
When creating "All Channels" timer on 8-channel device:
```
Timer1 {"Enable":1,"Mode":0,"Time":"07:00",...,"Output":1,"Action":1}
Timer2 {"Enable":1,"Mode":0,"Time":"07:00",...,"Output":2,"Action":1}
Timer3 {"Enable":1,"Mode":0,"Time":"07:00",...,"Output":3,"Action":1}
...
Timer8 {"Enable":1,"Mode":0,"Time":"07:00",...,"Output":8,"Action":1}
```

Each channel gets its own timer slot on the device!

## Future Enhancements

1. **Defragmentation**: Compact timers to free contiguous blocks
2. **Slot Visualization**: Visual diagram showing slot allocation
3. **Smart Suggestions**: "Delete Timer X to free 8 slots"
4. **Slot Reservation**: Reserve slots for future timers
5. **Migration Tool**: Convert local timers to Scene Control when limit reached
