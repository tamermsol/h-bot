# Device Removal Fix for Edit Scene

## Problem
When editing a scene and removing devices from the selected devices list, the removed devices were not being deleted from the database. The scene would continue to execute actions on the removed devices.

## Root Cause
The `onDevicesChanged` callback in `DeviceSelector` only updated `_selectedDevices` but did not clean up the corresponding entries in `_deviceActions` map. When the scene was saved:

1. User removes a device from `_selectedDevices`
2. The device's action remains in `_deviceActions` map
3. During save, all existing scene steps are deleted
4. New scene steps are created from `_deviceActions` (which still contains the removed device)
5. Result: Removed device's action is still saved to database

## Solution
Added a `_syncDeviceActions()` method that removes actions for devices that are no longer in `_selectedDevices`.

### Implementation

**1. Added sync call in device selection callback:**
```dart
DeviceSelector(
  selectedDevices: _selectedDevices,
  onDevicesChanged: (devices) {
    setState(() {
      _selectedDevices = devices;
      // Clean up device actions for removed devices
      _syncDeviceActions();
    });
  },
  accentColor: _selectedColor,
  homeId: widget.homeId,
),
```

**2. Created `_syncDeviceActions()` method:**
```dart
/// Sync device actions with selected devices
/// Removes actions for devices that are no longer selected
void _syncDeviceActions() {
  // Get list of currently selected device IDs
  final selectedDeviceIds = _selectedDevices
      .map((deviceMap) => deviceMap['id'] as String?)
      .where((id) => id != null)
      .cast<String>()
      .toSet();

  // Remove actions for devices that are no longer selected
  _deviceActions.removeWhere((deviceId, action) {
    final isRemoved = !selectedDeviceIds.contains(deviceId);
    if (isRemoved) {
      debugPrint('🗑️ Removed action for device: $deviceId');
    }
    return isRemoved;
  });

  debugPrint(
    '✅ Synced device actions: ${_deviceActions.length} actions for ${selectedDeviceIds.length} devices',
  );
}
```

## How It Works

1. **User removes a device**: When user deselects a device in `DeviceSelector`, `onDevicesChanged` is called
2. **Update selected devices**: `_selectedDevices` is updated with the new list
3. **Sync actions**: `_syncDeviceActions()` is called immediately
4. **Clean up**: The method extracts all device IDs from `_selectedDevices` and removes any actions in `_deviceActions` that don't have a corresponding selected device
5. **Save**: When scene is saved, only actions for currently selected devices are written to database

## Benefits

- ✅ Removed devices are properly deleted from scene
- ✅ No orphaned device actions in database
- ✅ Scene only executes actions on currently selected devices
- ✅ Works for both adding and removing devices
- ✅ Debug logging shows which devices are removed

## Testing

To verify the fix works:

1. **Edit an existing scene** with multiple devices
2. **Remove one or more devices** from the device selector
3. **Save the scene**
4. **Trigger the scene** (manually or via automation)
5. **Verify**: Removed devices should NOT execute any actions
6. **Check database**: Query `scene_steps` table to confirm removed devices have no entries

### SQL Query to Verify:
```sql
-- Check scene steps for a specific scene
SELECT 
  ss.id,
  ss.scene_id,
  ss.step_order,
  ss.action_json->>'device_id' as device_id,
  ss.action_json->>'action_type' as action_type
FROM scene_steps ss
WHERE ss.scene_id = 'YOUR_SCENE_ID'
ORDER BY ss.step_order;
```

## Files Modified

- `lib/screens/add_scene_screen.dart`
  - Added `_syncDeviceActions()` method
  - Updated `onDevicesChanged` callback to call sync method

## Related Issues

This fix also ensures:
- Adding new devices works correctly (actions are initialized in device actions step)
- Changing device selection multiple times works correctly
- No memory leaks from orphaned action data
