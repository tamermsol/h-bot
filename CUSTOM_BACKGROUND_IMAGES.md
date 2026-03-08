# Custom Background Images - Gallery & Camera

## What's New

Users can now add their own background images from:
- 📷 **Camera** - Take a photo directly
- 🖼️ **Gallery** - Choose from existing photos

Images are stored locally on the device (not uploaded to Supabase).

## Features

### 1. Default Backgrounds
- 5 pre-installed background images
- Bundled with the app
- Instant selection

### 2. Gallery Picker
- Choose from phone's photo library
- Supports JPG, PNG formats
- Automatically resized to 1920x1080
- Quality optimized to 85%

### 3. Camera
- Take a photo directly
- Same optimization as gallery
- Instant preview

### 4. Local Storage
- Images saved to app's documents directory
- Path: `/backgrounds/{userId}/{type}/{entityId}/`
- No internet required
- No Supabase storage needed
- Automatic cleanup when removed

## How It Works

### User Flow

```
Open Background Picker
    ↓
Choose Option:
├─> Select Default Background (5 options)
├─> Pick from Gallery
└─> Take Photo with Camera
    ↓
Image is saved locally
    ↓
Path stored in database
    ↓
Background appears on screen
```

### Storage Structure

```
App Documents Directory
└── backgrounds/
    └── {userId}/
        ├── home/
        │   └── {homeId}/
        │       └── 1234567890.jpg
        └── room/
            └── {roomId}/
                └── 1234567891.jpg
```

### Image Types

1. **Default Backgrounds**
   - Path: `assets/images/backgrounds/default_1.jpg`
   - Type: Asset
   - Storage: App bundle

2. **Custom Images**
   - Path: `/data/user/0/.../backgrounds/...jpg`
   - Type: Local file
   - Storage: App documents

3. **Network Images** (legacy support)
   - Path: `https://...`
   - Type: Network
   - Storage: External

## UI Changes

### Background Picker Dialog

```
┌─────────────────────────────────────┐
│  Room Background Image          [X] │
├─────────────────────────────────────┤
│                                     │
│  [Current Background Preview]       │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  Choose a Default Background        │
│                                     │
│  [img1] [img2] [img3] [img4] [img5] │
│  ← Scroll horizontally →            │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  Or Use Your Own Image              │
│                                     │
│  [📷 Gallery]  [📸 Camera]          │
│                                     │
├─────────────────────────────────────┤
│                                     │
│  [🗑️ Remove Background]             │
│                                     │
└─────────────────────────────────────┘
```

## Code Changes

### 1. Added Dependencies

**pubspec.yaml:**
```yaml
dependencies:
  image_picker: ^1.2.1
  path_provider: ^2.1.4  # NEW
```

### 2. Updated BackgroundImageService

**New Methods:**
- `pickImageFromCamera()` - Take photo with camera
- `saveImageLocally()` - Save image to app directory
- `deleteLocalImage()` - Delete local image file
- `isLocalFile()` - Check if path is local file

**Removed:**
- Supabase storage upload methods
- Network-based image handling

### 3. Updated BackgroundContainer

**New Support:**
- Display local file images using `Image.file()`
- Detect image type (asset, local, network)
- Graceful error handling

### 4. Updated BackgroundImagePicker

**New UI:**
- Gallery button
- Camera button
- Preview for all image types

**New Methods:**
- `_pickFromGallery()` - Handle gallery selection
- `_pickFromCamera()` - Handle camera capture
- `_pickAndSaveImage()` - Common save logic
- `_buildPreviewImage()` - Display preview

## Permissions Required

### Android (AndroidManifest.xml)

Already configured:
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### iOS (Info.plist)

May need to add:
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos for backgrounds</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to choose background images</string>
```

## Benefits

### For Users
- ✅ Use personal photos as backgrounds
- ✅ Take photos directly in app
- ✅ No internet required
- ✅ Instant preview
- ✅ Automatic optimization

### For Developers
- ✅ No Supabase storage costs
- ✅ No storage bucket setup
- ✅ Simpler architecture
- ✅ Offline support
- ✅ Better privacy

### For App
- ✅ Smaller backend footprint
- ✅ Faster image loading
- ✅ No network dependency
- ✅ Better performance
- ✅ Lower costs

## Image Optimization

All custom images are automatically:
- Resized to max 1920x1080
- Compressed to 85% quality
- Converted to appropriate format
- Saved efficiently

This ensures:
- Reasonable file sizes
- Fast loading
- Good quality
- Efficient storage

## Cleanup

When a background is removed:
1. Database entry is cleared
2. Local file is deleted (if custom)
3. Default backgrounds are preserved
4. No orphaned files

## Testing

### Test Gallery Picker
1. Open background picker
2. Tap "Gallery"
3. Select an image
4. See loading indicator
5. Image appears as background
6. Verify it persists after restart

### Test Camera
1. Open background picker
2. Tap "Camera"
3. Take a photo
4. See loading indicator
5. Image appears as background
6. Verify it persists after restart

### Test Remove
1. Select a custom background
2. Tap "Remove Background"
3. Confirm removal
4. Background is cleared
5. Local file is deleted

## Files Modified

- `pubspec.yaml` - Added path_provider
- `lib/services/background_image_service.dart` - Local storage support
- `lib/widgets/background_container.dart` - Local file display
- `lib/widgets/background_image_picker.dart` - Gallery & camera UI

## Migration Notes

### Existing Users

Users with existing backgrounds:
- Default backgrounds: Continue to work
- Network images: Continue to work (legacy support)
- New images: Saved locally

### Database

No migration needed:
- Column already exists: `background_image_url`
- Stores path (asset, local, or network)
- Backward compatible

## Summary

✅ Gallery picker added
✅ Camera support added
✅ Local storage implemented
✅ Image optimization included
✅ Automatic cleanup
✅ No Supabase storage needed
✅ Offline support
✅ Better performance

Users can now personalize their backgrounds with their own photos!
