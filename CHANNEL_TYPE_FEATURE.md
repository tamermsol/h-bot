# Channel Type Feature Implementation

## Overview
Added the ability to configure each relay device channel as either a **Light** or **Switch**, with customizable icons and persistent storage in the database.

## Features Implemented

### 1. Database Schema
- Added `channel_type` column to `device_channels` table (default: 'switch')
- Added check constraint to ensure valid types ('light' or 'switch')
- Created `update_channel_type()` RPC function for secure updates
- Updated `devices_with_channels` view to include channel type information

### 2. Data Models
- Updated `DeviceChannel` model with `channelType` field
- Added helper methods: `isLight()` and `isSwitch()`
- Updated `DeviceWithChannels` model with methods:
  - `getChannelType(int channelNo)` - Get type for specific channel
  - `isChannelLight(int channelNo)` - Check if channel is a light
  - `isChannelSwitch(int channelNo)` - Check if channel is a switch

### 3. Repository Layer
- Added `updateChannelType()` method to `DeviceManagementRepo`
- Added `updateChannelType()` method to `DevicesRepo`
- Proper error handling and authentication checks

### 4. UI Components

#### Device Control Screen
- Long-press on any channel opens options dialog
- Options dialog shows:
  - **Rename Channel** - Edit channel name
  - **Light** - Set channel as light (lightbulb icon)
  - **Switch** - Set channel as switch (power icon)
- Current selection is marked with a checkmark
- Circular channel buttons display appropriate icon based on type
- Optimistic UI updates with error rollback

#### Enhanced Device Control Widget
- Channel list shows appropriate icon (lightbulb or power)
- Icon color changes based on channel state (on/off)
- Loads channel types from database on initialization

#### Device Control Widget (Legacy)
- Added channel type support for backward compatibility
- Loads channel types alongside channel names

## User Experience

### How to Use
1. **Open Device Control Screen** - Navigate to any relay device
2. **Long-press on a Channel** - Press and hold on any channel button
3. **Select Channel Type** - Choose between:
   - 🔆 **Light** - For lighting circuits (shows lightbulb icon)
   - ⚡ **Switch** - For general switches (shows power icon)
4. **Rename Channel** (optional) - Give the channel a custom name

### Visual Indicators
- **Light channels**: Display 💡 lightbulb icon
- **Switch channels**: Display ⚡ power settings icon
- **Active state**: Icons and buttons highlight in primary color when ON
- **Inactive state**: Icons show in secondary color when OFF

## Database Migration

Run the migration to add channel type support:

```sql
-- File: supabase_migrations/add_channel_type.sql
-- This migration adds the channel_type column and related functions
```

The migration:
1. Adds `channel_type` column with default 'light'
2. Creates check constraint for valid types
3. Updates RPC functions to preserve channel type
4. Creates `update_channel_type()` function
5. Updates the `devices_with_channels` view

## Technical Details

### Channel Type Storage
- Stored in `device_channels.channel_type` column
- Valid values: 'light' or 'switch'
- Default: 'light'
- Persisted across app restarts

### State Management
- Channel types loaded on screen initialization
- Cached in local state maps for performance
- Optimistic updates with error rollback
- Synchronized with database on changes

### Icon Selection Logic
```dart
// In circular button
Icon(
  isLight ? Icons.lightbulb : Icons.power_settings_new,
  color: isOn ? Colors.white : AppTheme.textSecondary,
)

// In list view
Icon(
  _channelTypes[i] == 'light' 
    ? Icons.lightbulb 
    : Icons.power_settings_new,
  color: (_channelStates[i] ?? false) 
    ? AppTheme.primaryColor 
    : AppTheme.textSecondary,
)
```

## Files Modified

### Database
- `supabase_migrations/add_channel_type.sql` (new)

### Models
- `lib/models/device_channel.dart`
  - Added `channelType` field
  - Added helper methods

### Repositories
- `lib/repos/device_management_repo.dart`
  - Added `updateChannelType()` method
- `lib/repos/devices_repo.dart`
  - Added `updateChannelType()` method

### UI Components
- `lib/screens/device_control_screen.dart`
  - Added `_channelTypes` map
  - Added `_showChannelOptionsDialog()` method
  - Added `_updateChannelType()` method
  - Updated `_buildCircularChannelButton()` to show appropriate icon
  - Updated `_loadChannelNames()` to load channel types

- `lib/widgets/enhanced_device_control_widget.dart`
  - Added `_channelTypes` map
  - Updated `_loadChannelNames()` to load channel types
  - Updated `_buildMultiChannelControls()` to show icons

- `lib/widgets/device_control_widget.dart`
  - Added `_channelTypes` map
  - Updated `_loadChannelNames()` to load channel types

## Benefits

1. **Better Organization** - Distinguish between lighting and general switches
2. **Visual Clarity** - Appropriate icons make it easier to identify channel purpose
3. **User Customization** - Users can configure each channel independently
4. **Persistent Settings** - Configuration saved to database
5. **Backward Compatible** - Existing channels default to 'light' type

## Future Enhancements

Possible future improvements:
- Add more channel types (fan, outlet, etc.)
- Custom icons per channel type
- Channel type-specific controls (dimming for lights)
- Bulk channel type updates
- Channel type templates for common device configurations
