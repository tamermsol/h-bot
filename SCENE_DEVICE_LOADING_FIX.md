# Scene Device Loading Fix

## Problem
When creating a scene, the device selector shows "No devices found in this home. Add devices first." even though devices exist in the database.

## Root Cause
The `devices_with_channels` view was missing several critical columns that the Device model expects:
- `online` - Device online status
- `last_seen_at` - Last time device was seen
- `channel_count` - Logical channel count
- `is_deleted` - Deletion flag
- `deleted_at` - Deletion timestamp

Additionally, the view wasn't filtering out deleted devices.

## Solution

### Step 1: Run Diagnostic Queries
First, run the diagnostic queries to verify the issue:

```bash
# In Supabase SQL Editor, run:
supabase_migrations/diagnose_devices_issue.sql
```

This will show:
- Total devices in database
- Devices per home
- Devices in the view
- Devices without home_id
- Deleted devices
- Sample device data
- View column structure

### Step 2: Apply the Fix
Run the migration to fix the view:

```bash
# In Supabase SQL Editor, run:
supabase_migrations/fix_devices_with_channels_view.sql
```

This will:
1. Drop the old `devices_with_channels` view
2. Create a new view with all necessary columns
3. Filter out deleted devices
4. Include channel type information in channel_labels

### Step 3: Verify the Fix
After applying the migration, verify:

1. **Check the view has data:**
   ```sql
   SELECT COUNT(*) FROM devices_with_channels;
   ```

2. **Check devices for a specific home:**
   ```sql
   SELECT * FROM devices_with_channels 
   WHERE home_id = 'YOUR_HOME_ID_HERE';
   ```

3. **Test in the app:**
   - Navigate to Scenes tab
   - Click "Add Scene"
   - Go through the steps to "Select Devices"
   - Devices should now appear

## Code Changes Made

### 1. Added Debug Logging
Added debug logging to `DeviceSelector` widget to help diagnose issues:
- Logs when loading devices
- Logs the homeId being used
- Logs the number of devices loaded
- Logs any errors

### 2. Fixed Scenes Screen State Management
Modified `ScenesScreen` to reload data when the tab becomes visible:
- Added `AutomaticKeepAliveClientMixin` with `wantKeepAlive = false`
- Added `didChangeDependencies()` to reload scenes when tab is shown
- Ensures fresh data is loaded each time user navigates to Scenes tab

## Database View Structure

The fixed `devices_with_channels` view now includes:

```sql
- id
- tasmota_topic_base (mapped from topic_base)
- topic_base
- mac_address
- owner_user_id
- name (mapped from display_name)
- display_name
- name_is_custom
- channels
- channel_count (NEW)
- home_id
- room_id
- device_type
- matter_type
- meta_json
- created_at (mapped from inserted_at)
- inserted_at
- updated_at
- online (NEW)
- last_seen_at (NEW)
- is_deleted (NEW)
- deleted_at (NEW)
- channel_labels (with channel_type included)
```

## Testing Checklist

- [ ] Run diagnostic queries to verify device data exists
- [ ] Apply the view fix migration
- [ ] Verify view has all columns
- [ ] Test creating a new scene
- [ ] Verify devices appear in device selector
- [ ] Test selecting devices
- [ ] Test configuring device actions
- [ ] Test creating the scene successfully

## Troubleshooting

### Still No Devices Showing?

1. **Check if devices have home_id:**
   ```sql
   SELECT id, name, home_id FROM devices WHERE is_deleted = false;
   ```
   If devices have NULL home_id, assign them to a home.

2. **Check if user has access to the home:**
   ```sql
   SELECT h.* FROM homes h
   JOIN home_members hm ON hm.home_id = h.id
   WHERE hm.user_id = 'YOUR_USER_ID_HERE';
   ```

3. **Check RLS policies:**
   Ensure Row Level Security policies allow the user to read devices:
   ```sql
   SELECT * FROM devices_with_channels WHERE home_id = 'YOUR_HOME_ID';
   ```

4. **Check app logs:**
   Look for debug messages starting with "DeviceSelector:" in the console.

## Related Files
- `lib/widgets/device_selector.dart` - Device selector widget
- `lib/screens/scenes_screen.dart` - Scenes screen
- `lib/screens/add_scene_screen.dart` - Scene creation screen
- `lib/repos/devices_repo.dart` - Device repository
- `supabase_migrations/fix_devices_with_channels_view.sql` - View fix migration
- `supabase_migrations/diagnose_devices_issue.sql` - Diagnostic queries
