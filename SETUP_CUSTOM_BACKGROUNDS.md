# Setup Custom Background Images

## Quick Setup (2 Steps)

### Step 1: Install Dependencies

```cmd
flutter pub get
```

This installs the new `path_provider` package.

### Step 2: Test

Hot restart your app and test:

1. Open any room or home
2. Tap filter icon → Dashboard Background
3. You'll see:
   - 5 default backgrounds (scroll horizontally)
   - "Gallery" button
   - "Camera" button
   - "Remove Background" button (if selected)

## How to Use

### Select Default Background
1. Scroll through 5 default options
2. Tap any to select
3. Background appears instantly

### Use Gallery Image
1. Tap "Gallery" button
2. Choose image from phone
3. Wait for processing
4. Background appears

### Take Photo
1. Tap "Camera" button
2. Take a photo
3. Wait for processing
4. Background appears

### Remove Background
1. Tap "Remove Background"
2. Confirm removal
3. Background is cleared

## What Changed

### New Features
- ✅ Gallery picker
- ✅ Camera support
- ✅ Local storage
- ✅ Image optimization

### Removed
- ❌ Supabase storage upload
- ❌ Network dependency
- ❌ Storage bucket requirement

## Storage Location

Custom images are saved to:
```
/data/user/0/com.example.hbot/app_flutter/backgrounds/
└── {userId}/
    ├── home/{homeId}/
    └── room/{roomId}/
```

## Image Specs

All images are automatically:
- Max size: 1920x1080
- Quality: 85%
- Format: JPG/PNG
- Optimized for performance

## Permissions

### Android
Already configured in AndroidManifest.xml:
- Camera permission
- Storage read/write

### iOS
May need to add to Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>Take photos for backgrounds</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Choose background images</string>
```

## Testing Checklist

- [ ] Run `flutter pub get`
- [ ] Hot restart app
- [ ] Open background picker
- [ ] See 5 default backgrounds
- [ ] See Gallery and Camera buttons
- [ ] Test Gallery picker
- [ ] Test Camera
- [ ] Test Remove
- [ ] Verify persistence after restart

## Troubleshooting

### "Failed to save image"
- Check storage permissions
- Ensure enough disk space
- Try restarting app

### Camera doesn't open
- Check camera permission
- Ensure device has camera
- Try from Settings → App Permissions

### Gallery doesn't open
- Check storage permission
- Ensure photos exist
- Try restarting app

### Image doesn't appear
- Check file was saved
- Verify path in database
- Try hot restart

## Benefits

✅ No internet required
✅ No Supabase storage costs
✅ Faster loading
✅ Better privacy
✅ Offline support
✅ Personal photos

## Summary

1. Run `flutter pub get`
2. Hot restart app
3. Test gallery and camera
4. Enjoy custom backgrounds!

**Time:** 2 minutes
**Difficulty:** Easy
**Result:** Users can use their own photos as backgrounds!
