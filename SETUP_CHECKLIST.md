# Background Images Setup Checklist

## Quick Setup (5 minutes)

### Step 1: Add Background Images
- [ ] Double-click `setup_backgrounds.bat`
- [ ] Wait for download to complete (5 images)
- [ ] Verify 5 images in `assets/images/backgrounds/`

**OR manually:**
- [ ] Create folder: `assets\images\backgrounds\`
- [ ] Add 5 images named: `default_1.jpg`, `default_2.jpg`, `default_3.jpg`, `default_4.jpg`, `default_5.jpg`

### Step 2: Update Flutter
- [ ] Open terminal in project root
- [ ] Run: `flutter pub get`
- [ ] Wait for completion

### Step 3: Test
- [ ] Hot restart app (not hot reload)
- [ ] Open any room
- [ ] Tap settings icon (gear)
- [ ] Tap "Background Image"
- [ ] Verify you see gallery of 5 backgrounds
- [ ] Tap a background to select
- [ ] Verify background appears on screen
- [ ] Try selecting different backgrounds
- [ ] Try removing a background

## Verification Checklist

### Files Exist
- [ ] `assets/images/backgrounds/default_1.jpg`
- [ ] `assets/images/backgrounds/default_2.jpg`
- [ ] `assets/images/backgrounds/default_3.jpg`
- [ ] `assets/images/backgrounds/default_4.jpg`
- [ ] `assets/images/backgrounds/default_5.jpg`

### Code Updated
- [x] `lib/services/background_image_service.dart` - Modified
- [x] `lib/widgets/background_container.dart` - Modified
- [x] `lib/widgets/background_image_picker.dart` - Modified
- [x] `pubspec.yaml` - Modified

### Features Work
- [ ] Gallery shows 5 thumbnails
- [ ] Can scroll gallery horizontally
- [ ] Tapping a background selects it
- [ ] Selected background has blue border
- [ ] Background appears on screen
- [ ] Can switch between backgrounds
- [ ] Can remove background
- [ ] "Upload Custom" button exists
- [ ] No errors in console

## Troubleshooting

### Gallery shows gray boxes
**Problem:** Images not loaded
**Solution:**
- [ ] Check images exist in `assets/images/backgrounds/`
- [ ] Check filenames are exact: `default_1.jpg` etc.
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Full restart (not hot reload)

### Images don't appear on screen
**Problem:** Asset not registered
**Solution:**
- [ ] Check `pubspec.yaml` has `assets/images/backgrounds/`
- [ ] Run: `flutter pub get`
- [ ] Full restart

### Upload Custom fails
**Problem:** No Supabase bucket
**Solution:**
- [ ] This is expected if bucket doesn't exist
- [ ] Default backgrounds still work
- [ ] To enable: Create `background-images` bucket in Supabase
- [ ] Make bucket public

### App crashes
**Problem:** Code error
**Solution:**
- [ ] Check console for error message
- [ ] Verify all code changes applied correctly
- [ ] Run: `flutter clean && flutter pub get`
- [ ] Full rebuild

## Optional: Enable Custom Uploads

If you want users to upload custom images:

- [ ] Go to Supabase Dashboard
- [ ] Navigate to Storage
- [ ] Create new bucket: `background-images`
- [ ] Make bucket public
- [ ] Test upload in app

## Success Criteria

✅ Gallery shows 5 background thumbnails
✅ Can select any background instantly
✅ Background appears on room/home screen
✅ Can switch between backgrounds
✅ Can remove background
✅ No errors in console
✅ Works without internet (default backgrounds)

## Next Steps After Setup

1. **Test thoroughly**
   - Try all 5 backgrounds
   - Test on different rooms
   - Test on home dashboard
   - Test remove functionality

2. **Optional: Add more backgrounds**
   - Add more images to `assets/images/backgrounds/`
   - Update `BackgroundImageService.defaultBackgrounds` list
   - Run `flutter pub get`
   - Restart app

3. **Optional: Customize images**
   - Replace default images with your own
   - Keep same filenames
   - Recommended: 1920x1080, under 500KB each

## Support Documents

- `QUICK_START_BACKGROUNDS.md` - Quick setup guide
- `BACKGROUND_IMAGES_FIX.md` - Complete summary
- `BACKGROUND_PICKER_UI.md` - UI explanation
- `BACKGROUND_FLOW_DIAGRAM.md` - Architecture diagram
- `IMPLEMENTATION_COMPLETE.md` - What was done

## Done!

Once all checkboxes are checked, your background images feature is ready! 🎉
