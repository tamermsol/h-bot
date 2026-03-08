# Default Repeat Option Changed to "Once Only"

## Change Summary
Changed the default repeat option for time-based scene triggers from "Every day" to "Once only".

## What Changed

### Before:
- Default repeat: "Every day"
- Default days: `[1, 2, 3, 4, 5, 6, 7]` (all days)
- Scene would trigger every day at the specified time

### After:
- Default repeat: "Once only"
- Default days: `[]` (empty, will be set to current weekday when saved)
- Scene will trigger on the next occurrence of the specified time

## Implementation Details

**File**: `lib/screens/add_scene_screen.dart`

**Changes**:
```dart
// Before:
String _selectedRepeat = 'Every day';
List<int> _customDays = [1, 2, 3, 4, 5, 6, 7];

// After:
String _selectedRepeat = 'Once only';
List<int> _customDays = [];
```

## How "Once Only" Works

When user selects "Once only" and saves the scene:

1. **Day Selection**: The `_getDaysFromRepeatOption()` method automatically uses the current weekday:
   ```dart
   case 'Once only':
     final now = DateTime.now();
     return [now.weekday]; // e.g., [3] for Wednesday
   ```

2. **Trigger Behavior**: The scene will trigger on the next occurrence of the specified time on that weekday

3. **Example**:
   - User creates scene on Wednesday at 2:00 PM
   - User sets trigger time to 6:00 PM
   - Scene will trigger at 6:00 PM on Wednesday
   - If it's already past 6:00 PM, it will trigger next Wednesday at 6:00 PM

## Important Notes

### Current Behavior
The "Once only" option currently means "once per week on this day" because:
- The trigger stores a specific weekday in the `days` array
- The edge function checks if current day matches the stored day
- The trigger remains enabled after firing

### True "Once Only" Behavior
To make it truly fire only once ever, you would need to:
1. Add logic to automatically disable the trigger after it fires
2. Or add a "last_triggered_at" timestamp and check if it's already been triggered

### Recommendation for Users
If you want a scene to trigger only once:
1. Create the scene with "Once only" repeat option
2. After the scene triggers, manually disable it or delete it
3. Or use the "Manual" trigger type and activate it manually when needed

## User Experience

### Creating New Scene:
1. User selects "Time Based" trigger
2. Default repeat is now "Once only" (instead of "Every day")
3. User can change to other options if needed:
   - Every day
   - Monday to Friday
   - Weekend
   - Custom

### Editing Existing Scene:
- Existing scenes keep their current repeat option
- Only new scenes default to "Once only"

## Benefits

✅ More intuitive default - most users want one-time triggers
✅ Prevents accidental daily repetition
✅ Users can still easily change to "Every day" if needed
✅ Reduces unnecessary scene executions

## Testing

To verify the change:

1. **Create new time-based scene**:
   - Go to Create Scene
   - Select "Time Based" trigger
   - Verify repeat shows "Once only" by default

2. **Change repeat option**:
   - Click on repeat selector
   - Verify all options are available
   - Select different option and verify it saves

3. **Edit existing scene**:
   - Edit a scene with "Every day" repeat
   - Verify it still shows "Every day" (not changed to "Once only")

## Files Modified

- `lib/screens/add_scene_screen.dart`
  - Changed `_selectedRepeat` default from "Every day" to "Once only"
  - Changed `_customDays` default from `[1,2,3,4,5,6,7]` to `[]`
