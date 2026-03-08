# Room Background Removal Fix

## Issue
When the user removes the background from a room, the background image was still showing in the rooms list. The room was not properly updated in the database to clear the background.

## Root Cause
The `RoomsRepo.updateRoom()` method had a bug where it only updated `background_image_url` when the value was NOT null:

```dart
if (backgroundImageUrl != null)
  updates['background_image_url'] = backgroundImageUrl;
```

This meant that when the user removed the background (passing `null`), the database was never updated to clear the field.

## Solution

### 1. Updated RoomsRepo.updateRoom() Method
Added a `clearBackground` parameter to explicitly handle background removal:

```dart
Future<Room> updateRoom(
  String roomId, {
  String? name,
  int? sortOrder,
  String? backgroundImageUrl,
  bool clearBackground = false,  // NEW PARAMETER
}) async {
  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toIso8601String(),
  };

  if (name != null) updates['name'] = name;
  if (sortOrder != null) updates['sort_order'] = sortOrder;
  
  // Handle background image: explicit null to remove, or new URL to set
  if (clearBackground) {
    updates['background_image_url'] = null;  // EXPLICITLY SET TO NULL
  } else if (backgroundImageUrl != null) {
    updates['background_image_url'] = backgroundImageUrl;
  }

  // ... rest of method
}
```

### 2. Updated RoomsScreen._showBackgroundImageDialog()
Modified the callback to use the `clearBackground` flag when removing background:

```dart
onImageSelected: (imageUrl) async {
  try {
    // If imageUrl is null, we're removing the background
    if (imageUrl == null) {
      await _roomsRepo.updateRoom(
        room.id,
        clearBackground: true,  // EXPLICITLY CLEAR
      );
    } else {
      await _roomsRepo.updateRoom(
        room.id,
        backgroundImageUrl: imageUrl,
      );
    }

    // Reload rooms to get updated data
    await _loadRooms();

    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e) {
    // ... error handling
  }
}
```

## How It Works Now

1. User clicks "Remove Background" in the BackgroundImagePicker
2. BackgroundImagePicker calls `onImageSelected(null)`
3. RoomsScreen detects `imageUrl == null` and calls `updateRoom()` with `clearBackground: true`
4. RoomsRepo explicitly sets `background_image_url` to `null` in the database
5. Rooms list is reloaded with updated data
6. Room card now shows without background image

## Testing

- [x] Create a new room (no background) - works correctly
- [x] Add background to room - works correctly
- [x] Remove background from room - NOW WORKS (was broken before)
- [x] Room list updates immediately after removal
- [x] Room card displays correctly without background

## Files Modified

1. `lib/repos/rooms_repo.dart` - Added `clearBackground` parameter to `updateRoom()`
2. `lib/screens/rooms_screen.dart` - Updated `_showBackgroundImageDialog()` to handle null imageUrl

## Note on Home Background
The home background removal already works correctly because `HomesRepo.updateHomeBackgroundImage()` directly accepts and sets null values without any conditional check.
