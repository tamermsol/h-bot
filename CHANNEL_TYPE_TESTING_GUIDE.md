# Channel Type Feature - Testing Guide

## Prerequisites
1. Run the database migration first:
   ```bash
   # Apply the migration to your Supabase database
   # File: supabase_migrations/add_channel_type.sql
   ```

2. Rebuild the app to include the new code:
   ```bash
   flutter clean
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter run
   ```

## Test Scenarios

### Test 1: View Default Channel Types
**Objective**: Verify all existing channels default to 'light' type

1. Open the app and navigate to any relay device
2. Observe the channel buttons/list
3. **Expected**: All channels show lightbulb icon (💡) by default

### Test 2: Change Channel to Switch
**Objective**: Change a channel from light to switch

1. Navigate to a relay device control screen
2. Long-press on any channel button
3. Select "Switch" from the options dialog
4. **Expected**: 
   - Dialog closes
   - Success message appears: "Channel X changed to Switch"
   - Channel icon changes to power icon (⚡)
   - Change persists after closing and reopening the screen

### Test 3: Change Channel to Light
**Objective**: Change a switch channel back to light

1. Long-press on a channel that's configured as switch
2. Select "Light" from the options dialog
3. **Expected**:
   - Dialog closes
   - Success message appears: "Channel X changed to Light"
   - Channel icon changes to lightbulb (💡)
   - Change persists after closing and reopening the screen

### Test 4: Rename Channel with Type Preserved
**Objective**: Verify channel type is preserved when renaming

1. Long-press on a channel configured as switch
2. Select "Rename Channel"
3. Enter a new name (e.g., "Kitchen Switch")
4. Save the change
5. **Expected**:
   - Channel name updates
   - Channel type remains as switch (⚡ icon)
   - Both name and type persist after app restart

### Test 5: Multiple Channels with Different Types
**Objective**: Configure different types for different channels

1. Navigate to a multi-channel relay device (2, 4, or 8 channels)
2. Configure channels as follows:
   - Channel 1: Light (default)
   - Channel 2: Switch
   - Channel 3: Light (default)
   - Channel 4: Switch
3. **Expected**:
   - Each channel shows the correct icon
   - Icons update immediately after selection
   - Configuration persists after closing and reopening

### Test 6: Icon Color Changes with State
**Objective**: Verify icons change color based on ON/OFF state

1. Configure a channel as switch
2. Turn the channel ON
3. **Expected**: Power icon shows in primary color (bright)
4. Turn the channel OFF
5. **Expected**: Power icon shows in secondary color (dim)

### Test 7: Enhanced Device Control Widget
**Objective**: Test channel types in the dashboard/home screen

1. Navigate to home dashboard
2. Find a relay device card
3. **Expected**:
   - Channels show appropriate icons (💡 or ⚡)
   - Icons match the configuration from device control screen
   - Icons change color based on state

### Test 8: Options Dialog UI
**Objective**: Verify the options dialog displays correctly

1. Long-press on any channel
2. **Expected**:
   - Dialog shows channel name in title
   - Three options visible:
     - "Rename Channel" with edit icon
     - "Light" with lightbulb icon
     - "Switch" with power icon
   - Current selection has a checkmark
   - Selected option highlighted in primary color
   - Non-selected option in secondary color

### Test 9: Error Handling
**Objective**: Test error handling when update fails

1. Disconnect from internet/database
2. Long-press on a channel
3. Try to change the channel type
4. **Expected**:
   - Error message appears
   - Channel type reverts to previous value
   - UI remains functional

### Test 10: Persistence Across App Restarts
**Objective**: Verify channel types persist after app restart

1. Configure several channels with different types
2. Close the app completely
3. Restart the app
4. Navigate to the device
5. **Expected**:
   - All channel types are preserved
   - Icons match the previous configuration

## Database Verification

You can verify the database directly:

```sql
-- Check channel types for a specific device
SELECT 
  device_id,
  channel_no,
  label,
  channel_type,
  label_is_custom
FROM device_channels
WHERE device_id = 'YOUR_DEVICE_ID'
ORDER BY channel_no;

-- Check the view includes channel types
SELECT 
  id,
  display_name,
  channel_labels
FROM devices_with_channels
WHERE id = 'YOUR_DEVICE_ID';
```

## Expected Results Summary

✅ **All tests should pass with:**
- Immediate UI updates (optimistic)
- Persistent storage in database
- Correct icon display (💡 for light, ⚡ for switch)
- Color changes based on state
- Error handling with rollback
- Consistent behavior across all device control widgets

## Known Limitations

1. Channel type only applies to relay devices
2. Shutter devices don't support channel type configuration
3. Single-channel devices show switch control (not affected by type)

## Troubleshooting

### Icons not updating
- Check if migration was applied successfully
- Verify `channel_type` column exists in database
- Check browser console for errors

### Changes not persisting
- Verify RPC function `update_channel_type` exists
- Check RLS policies allow updates
- Verify user authentication

### Error messages
- Check Supabase connection
- Verify device ownership
- Check channel number is valid (1-8)
