# Avatar Feature Setup

## Overview
The app now supports custom profile avatars with the following options:
- 6 default avatars bundled with the app
- Pick image from gallery
- Take photo with camera
- Images stored locally on device

## Setup Instructions

### 1. Create Avatar Assets Directory
Create the following directory structure:
```
assets/
  images/
    avatars/
      avatar_1.png
      avatar_2.png
      avatar_3.png
      avatar_4.png
      avatar_5.png
      avatar_6.png
```

### 2. Add Avatar Images
Add 6 default avatar images (PNG format, recommended size: 512x512px) to the `assets/images/avatars/` directory.

You can use:
- Simple colored circles with initials
- Icon-based avatars
- Cartoon/illustrated avatars
- Abstract patterns

### 3. Update pubspec.yaml
The avatars are already configured in pubspec.yaml:
```yaml
assets:
  - assets/images/avatars/
```

### 4. Generate Default Avatars (Optional)
If you don't have avatar images, you can create simple ones using any image editor or online tools:

**Simple Colored Circles:**
- avatar_1.png: Blue circle
- avatar_2.png: Green circle
- avatar_3.png: Purple circle
- avatar_4.png: Orange circle
- avatar_5.png: Pink circle
- avatar_6.png: Teal circle

**Or use free avatar generators:**
- https://avatar.iran.liara.run/
- https://ui-avatars.com/
- https://avatars.dicebear.com/

## Features

### User Can:
1. **Tap avatar** on profile screen to open picker
2. **Choose from 6 default avatars** - bundled with app
3. **Pick from gallery** - select existing photo
4. **Take photo** - use camera to capture new photo
5. **Avatar persists** - saved locally using SharedPreferences

### Technical Details:
- **Storage**: Custom avatars saved to app documents directory
- **Path**: `/avatars/custom_avatar_{timestamp}.jpg`
- **Size**: Images automatically resized to 512x512px
- **Quality**: 85% JPEG compression
- **Persistence**: Path stored in SharedPreferences

## Files Modified/Created:
- `lib/services/avatar_service.dart` - Avatar management service
- `lib/widgets/avatar_picker_dialog.dart` - Avatar picker UI
- `lib/screens/profile_screen.dart` - Updated to show avatar
- `assets/images/avatars/` - Default avatar images (needs to be added)

## Testing:
1. Run the app
2. Navigate to Profile screen
3. Tap on the avatar (circular image with edit icon)
4. Select a default avatar OR pick from gallery/camera
5. Avatar should update immediately
6. Restart app - avatar should persist

## Notes:
- Requires `image_picker` and `path_provider` packages (already in pubspec.yaml)
- Camera permission required for camera feature
- Gallery permission required for gallery feature
- Works offline - all data stored locally
