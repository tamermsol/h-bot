# Background Images - Quick Setup Guide

## Step 1: Apply Database Migration

Run the migration to add background image support to your Supabase database:

```bash
# If using Supabase CLI
supabase db push

# Or manually run the SQL in Supabase Dashboard
# Copy contents of: supabase_migrations/add_background_images.sql
# Paste into SQL Editor in Supabase Dashboard and execute
```

## Step 2: Verify Storage Bucket

1. Go to your Supabase Dashboard
2. Navigate to Storage
3. Verify that `background-images` bucket exists
4. Check that it's set to public
5. Verify storage policies are in place

## Step 3: Test the Feature

### Test Room Background:
1. Open the app
2. Navigate to Rooms screen
3. Tap the three-dot menu on any room card
4. Select "Background Image"
5. Tap "Add Background"
6. Select an image from your gallery
7. Verify the image uploads and displays on the room card

### Test Dashboard Background:
1. Go to Home Dashboard
2. Tap the settings icon (⚙️) next to the home name
3. Select "Dashboard Background"
4. Tap "Add Background"
5. Select an image from your gallery
6. Verify the image uploads and displays as dashboard background

## Step 4: Verify Functionality

- [ ] Images upload successfully
- [ ] Images display correctly on room cards
- [ ] Images display correctly on dashboard
- [ ] Text remains readable over images (gradient overlay)
- [ ] "Change Background" works
- [ ] "Remove Background" works
- [ ] Images persist after app restart
- [ ] Multiple rooms can have different backgrounds
- [ ] Different homes can have different backgrounds

## Troubleshooting

### Images not uploading
- Check internet connection
- Verify Supabase project is active
- Check storage quota in Supabase
- Verify user is authenticated

### Images not displaying
- Check browser console for errors
- Verify image URL is valid
- Check storage bucket is public
- Verify storage policies are correct

### Permission errors
- Ensure user is authenticated
- Check storage policies in Supabase
- Verify bucket permissions

## Platform-Specific Notes

### Android
- Requires `READ_EXTERNAL_STORAGE` permission (handled by image_picker)
- Works on Android 10+ with scoped storage

### iOS
- Requires photo library permission (handled by image_picker)
- Add to Info.plist if not already present:
  ```xml
  <key>NSPhotoLibraryUsageDescription</key>
  <string>We need access to your photo library to set background images</string>
  ```

### Web
- Works with file picker
- No special permissions needed

## Next Steps

After successful testing:
1. Consider adding image caching for better performance
2. Add image compression options
3. Consider adding preset backgrounds
4. Add ability to crop/adjust images before upload
