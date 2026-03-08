# Fix Channel Type Persistence Issue

## Problem
Channel types are saved to database correctly, but when reopening the device page, all channels show as 'light' instead of their saved types.

## Root Cause
The `getDeviceWithChannels` method was using an RPC function that might not include the updated `channel_type` field. Changed to use the `devices_with_channels` view directly.

## Solution Applied

### 1. Updated Repository Method ✅
Changed `getDeviceWithChannels` to query the view directly instead of using RPC function.

**File**: `lib/repos/device_management_repo.dart`

### 2. Added Debug Logging ✅
Added comprehensive logging to track:
- When channel types are loaded
- What data is received from database
- What types are being displayed

**Files**:
- `lib/repos/device_management_repo.dart`
- `lib/screens/device_control_screen.dart`

## Testing Steps

1. **Restart your Flutter app**
2. **Open a device and change a channel type**:
   - Long-press on Channel 1
   - Select "Switch"
   - Verify icon changes to ⚡
3. **Close the device page**
4. **Reopen the device page**
5. **Check the logs** (look for these emojis):
   - 🔍 Getting device with channels
   - 📦 Device data received
   - 📋 Channel labels
   - 📌 Channel X: type="switch"
   - ✅ Loaded channel types

## Expected Behavior

Channel 1 should still show ⚡ (switch icon) after reopening.

## If Still Not Working

Run these diagnostic queries in Supabase SQL Editor:

```sql
-- Check your device's channel data
SELECT * FROM device_channels 
WHERE device_id = 'YOUR_DEVICE_ID'
ORDER BY channel_no;

-- Check the view output
SELECT id, display_name, channel_labels 
FROM devices_with_channels 
WHERE id = 'YOUR_DEVICE_ID';
```

The `channel_labels` should look like:
```json
{
  "1": {"label": "Channel 1", "is_custom": false, "type": "switch"},
  "2": {"label": "test2", "is_custom": true, "type": "light"}
}
```

## Files Changed
- ✅ `lib/repos/device_management_repo.dart` - Use view directly
- ✅ `lib/screens/device_control_screen.dart` - Added debug logging
