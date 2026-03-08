# Room Background in Devices View (Full Room View)

## Feature Added
Added room background image display to the DevicesScreen (the full room view that shows all devices in a room).

## Implementation

### Changes to DevicesScreen

#### 1. Added BackgroundContainer Import
```dart
import '../widgets/background_container.dart';
```

#### 2. Wrapped Body in Stack with Background Layer
Modified the `build()` method to wrap the body content in a Stack with a background layer:

```dart
body: Stack(
  children: [
    // Background image layer (only for room view)
    if (widget.room?.backgroundImageUrl != null &&
        widget.room!.backgroundImageUrl!.isNotEmpty)
      Positioned.fill(
        child: BackgroundContainer(
          backgroundImageUrl: widget.room!.backgroundImageUrl,
          overlayColor: isDark ? Colors.black : Colors.white,
          overlayOpacity: isDark ? 0.3 : 0.7,
          child: const SizedBox.expand(),
        ),
      ),
    // Content layer (existing UI)
    // ... search, filters, device grid
  ],
)
```

## How It Works

1. **Conditional Display**: Background only shows when:
   - User is viewing a specific room (`widget.room != null`)
   - Room has a background image set (`backgroundImageUrl` is not null/empty)

2. **Theme-Aware Overlay**:
   - **Dark Mode**: Black overlay at 30% opacity (subtle, maintains visibility)
   - **Light Mode**: White overlay at 70% opacity (keeps content readable)

3. **Consistent with Other Screens**:
   - Uses same `BackgroundContainer` widget as Dashboard and Rooms list
   - Same overlay opacity values for consistency
   - Same theme-aware behavior

## User Experience

### Before
- Rooms list showed background images on room cards
- Clicking into a room showed plain white/dark background
- Inconsistent visual experience

### After
- Rooms list shows background images on room cards ✅
- Clicking into a room shows the SAME background image ✅
- Consistent visual experience throughout the app ✅
- Background persists while browsing devices in the room ✅

## Visual Flow

```
Rooms List (with backgrounds)
    ↓ [User taps room card]
Room Devices View (with SAME background)
    ↓ [User taps device]
Device Control (no background - focused on controls)
```

## Files Modified

- `lib/screens/devices_screen.dart`
  - Added `BackgroundContainer` import
  - Wrapped body in Stack with background layer
  - Added conditional background display for room view

## Testing Checklist

- [x] Room with background image shows background in devices view
- [x] Room without background shows plain background
- [x] Background displays correctly in Light Mode (white overlay 70%)
- [x] Background displays correctly in Dark Mode (black overlay 30%)
- [x] Device cards remain readable over background
- [x] Search and filters work correctly with background
- [x] Background matches the one shown in rooms list
- [x] Home devices view (no room) shows no background

## Notes

- Background only applies to room-specific device views
- When viewing all devices for a home (no specific room), no background is shown
- This maintains focus on devices when viewing home-wide device list
- Background removal from rooms list also removes it from devices view (they share the same `room.backgroundImageUrl`)
