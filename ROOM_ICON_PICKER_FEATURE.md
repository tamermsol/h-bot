# Room Icon Picker Feature

## Overview
Added a custom icon picker feature that allows users to choose from 38 different icons for their rooms, with smart auto-detection as a fallback.

## Features

### 1. Icon Picker Widget (`RoomIconPicker`)
A comprehensive icon picker with 38 room-specific icons organized in a grid:

**Categories:**
- **Bedrooms**: bed, single_bed, king_bed
- **Living Areas**: weekend, chair, event_seat
- **Kitchen/Dining**: kitchen, dining, restaurant
- **Bathrooms**: bathtub, shower, hot_tub
- **Work Spaces**: desk, computer, work
- **Outdoor**: garage, directions_car, grass, yard, deck, balcony, pool
- **Entertainment**: fitness_center, sports_esports, tv, movie, library_books
- **Children**: child_care, toys
- **Utility**: checkroom, dry_cleaning, local_laundry_service, storage, warehouse
- **Other**: stairs, door_sliding, meeting_room, room

### 2. Smart Icon Detection
If no custom icon is set, the system automatically detects the appropriate icon based on the room name:
- "Living Room" → weekend icon
- "Kitchen" → kitchen icon
- "Bedroom" → bed icon
- "Bathroom" → bathtub icon
- "Office" → desk icon
- "Garage" → garage icon
- "Garden" → grass icon
- Default → room icon

### 3. Database Integration
- Added `icon_name` column to `rooms` table
- Migration file: `supabase_migrations/add_room_icon.sql`
- Stores icon name as string (e.g., 'bed', 'kitchen', 'garage')

## Implementation

### Files Created
1. **`lib/widgets/room_icon_picker.dart`**
   - Grid-based icon picker with 38 icons
   - Visual selection with highlighting
   - Static method `getIconData()` to convert icon name to IconData

### Files Modified
1. **`lib/screens/rooms_screen.dart`**
   - Added import for `RoomIconPicker`
   - Updated `_getRoomIcon()` to use custom icon if set
   - Added `_showIconPickerDialog()` method
   - Added "Change Icon" option to popup menu

2. **`lib/repos/rooms_repo.dart`**
   - Already had `iconName` parameter in `updateRoom()` method

3. **`lib/models/room.dart`**
   - Already had `iconName` field

### Database Migration
```sql
-- Add icon_name column to rooms table
ALTER TABLE rooms ADD COLUMN icon_name TEXT;

-- Add comment
COMMENT ON COLUMN rooms.icon_name IS 'Custom icon name for the room (e.g., bed, kitchen, garage)';
```

## User Experience

### Setting a Custom Icon
1. Navigate to Rooms screen
2. Tap the three-dot menu on any room card
3. Select "Change Icon"
4. Choose from 38 available icons
5. Icon updates immediately

### Icon Display
- Room cards show the custom icon if set
- Falls back to smart detection if no custom icon
- Icons are color-coded:
  - Blue background when selected in picker
  - Primary blue color for room icon on cards

## Code Examples

### Using the Icon Picker
```dart
RoomIconPicker(
  currentIconName: room.iconName,
  onIconSelected: (iconName) async {
    await _roomsRepo.updateRoom(
      room.id,
      iconName: iconName,
    );
  },
)
```

### Getting Icon Data
```dart
IconData icon = RoomIconPicker.getIconData('bed'); // Returns Icons.bed
IconData icon = RoomIconPicker.getIconData(null); // Returns Icons.room (default)
```

### Smart Detection
```dart
IconData _getRoomIcon(Room room) {
  // Use custom icon if set
  if (room.iconName != null && room.iconName!.isNotEmpty) {
    return RoomIconPicker.getIconData(room.iconName);
  }

  // Fallback to smart detection
  final name = room.name.toLowerCase();
  if (name.contains('living')) return Icons.weekend;
  if (name.contains('kitchen')) return Icons.kitchen;
  // ... more detection logic
  return Icons.room; // default
}
```

## Testing Checklist

- [x] Icon picker displays all 38 icons
- [x] Selected icon is highlighted
- [x] Icon selection updates database
- [x] Room card displays custom icon
- [x] Smart detection works when no custom icon
- [x] Icon persists after app restart
- [x] Theme-aware styling (Light/Dark mode)
- [x] Popup menu includes "Change Icon" option
- [x] Success message shows after icon update

## Benefits

1. **Personalization**: Users can customize room icons to match their preferences
2. **Visual Organization**: Different icons help quickly identify rooms
3. **Smart Defaults**: Auto-detection provides good defaults without user action
4. **Easy to Use**: Simple grid-based picker with visual feedback
5. **Comprehensive**: 38 icons cover most common room types

## Future Enhancements

Potential improvements for future versions:
- Add more icons (e.g., laundry, pantry, mudroom)
- Allow custom icon colors
- Icon search/filter functionality
- Recently used icons section
- Icon categories/tabs for easier navigation
