# Background Images Feature

## Overview
This feature allows users to add custom background images to rooms and the main dashboard, providing a personalized and visually appealing experience.

## Implementation Summary

### 1. Database Changes
- **Migration File**: `supabase_migrations/add_background_images.sql`
- Added `background_image_url` column to `rooms` table
- Added `background_image_url` column to `homes` table
- Created `background-images` storage bucket in Supabase
- Set up storage policies for authenticated users to upload/manage their images
- Public read access for background images

### 2. Model Updates
- **Home Model** (`lib/models/home.dart`): Added `backgroundImageUrl` field
- **Room Model** (`lib/models/room.dart`): Added `backgroundImageUrl` field
- Both models updated with proper JSON serialization

### 3. Repository Updates
- **RoomsRepo** (`lib/repos/rooms_repo.dart`): Added `backgroundImageUrl` parameter to `updateRoom` method
- **HomesRepo** (`lib/repos/homes_repo.dart`): Added `updateHomeBackgroundImage` method

### 4. New Services
- **BackgroundImageService** (`lib/services/background_image_service.dart`)
  - `pickImageFromGallery()`: Opens image picker
  - `uploadBackgroundImage()`: Uploads image to Supabase Storage
  - `deleteBackgroundImage()`: Removes image from storage
  - `removeBackgroundImage()`: Cleans up old images
  - Images are automatically resized to 1920x1080 with 85% quality

### 5. New Widgets
- **BackgroundImagePicker** (`lib/widgets/background_image_picker.dart`)
  - Reusable widget for selecting/uploading background images
  - Shows current image preview
  - Add/Change/Remove buttons
  - Handles loading states and error messages

- **BackgroundContainer** (`lib/widgets/background_container.dart`)
  - Displays background image with optional overlay
  - Ensures content readability with gradient overlay
  - Graceful error handling for failed image loads

### 6. UI Updates

#### Rooms Screen (`lib/screens/rooms_screen.dart`)
- Added "Background Image" option to room context menu
- Room cards display background images with gradient overlay
- Text color adapts based on background (white text on images)
- Dialog for managing room background images

#### Home Dashboard Screen (`lib/screens/home_dashboard_screen.dart`)
- Dashboard background displays home's background image
- Transparent scaffold with overlay for readability
- Background persists across all dashboard views

## Usage

### For Rooms:
1. Navigate to Rooms screen
2. Tap the three-dot menu on any room card
3. Select "Background Image"
4. Choose "Add Background" or "Change Background"
5. Select an image from your gallery
6. Image uploads automatically and displays on the room card

### For Home Dashboard:
1. Navigate to Home Dashboard
2. Tap the three-dot menu in the header (next to home name)
3. Select "Dashboard Background"
4. Choose "Add Background" or "Change Background"
5. Select an image from your gallery
6. Image uploads and displays as dashboard background

## Storage Structure
Images are stored in Supabase Storage with the following path structure:
```
background-images/
  {user_id}/
    home/
      {home_id}/
        {timestamp}.{ext}
    room/
      {room_id}/
        {timestamp}.{ext}
```

## Security
- Only authenticated users can upload images
- Users can only upload to their own folder (user_id)
- Users can only modify/delete their own images
- Public read access allows images to be displayed to all users

## Dependencies
- `image_picker`: For selecting images from gallery
- `supabase_flutter`: For storage and database operations

## Next Steps
To apply this feature:

1. **Run the migration**:
   ```bash
   # Apply the migration to your Supabase project
   supabase db push
   ```

2. **Regenerate model files** (if using json_serializable):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Test the feature**:
   - Add background to a room
   - Add background to home dashboard
   - Verify images display correctly
   - Test remove functionality
   - Check storage policies in Supabase dashboard

## Troubleshooting

### Images not displaying
- Check Supabase Storage bucket exists and is public
- Verify storage policies are correctly set
- Check network connectivity
- Verify image URL is valid

### Upload fails
- Ensure user is authenticated
- Check storage quota in Supabase
- Verify image file size is reasonable
- Check Supabase project settings

### Performance issues
- Images are automatically optimized (1920x1080, 85% quality)
- Consider implementing image caching
- Use CDN for better performance (Supabase provides this)
