# Default Background Images Setup

## Overview
The app now supports default background images bundled with the app, eliminating the need for Supabase storage bucket setup and allowing users to choose backgrounds without uploading.

## Changes Made

### 1. Updated Background Image Service
- Added list of default background paths
- Added `isDefaultBackground()` method to check if a URL is a default asset
- Modified delete methods to skip deletion for default backgrounds

### 2. Updated Background Container
- Now supports both asset images (default backgrounds) and network images (custom uploads)
- Automatically detects image type and uses appropriate loader

### 3. Updated Background Image Picker
- Added horizontal scrollable gallery of default backgrounds
- Users can tap to select a default background
- "Upload Custom" button for users who want to upload their own images
- Selected background is highlighted with a border

### 4. Updated pubspec.yaml
- Added `assets/images/backgrounds/` to asset paths

## Adding Default Background Images

You need to add 5 default background images to your project:

1. Create the folder: `assets/images/backgrounds/`

2. Add 5 images with these exact names:
   - `default_1.jpg`
   - `default_2.jpg`
   - `default_3.jpg`
   - `default_4.jpg`
   - `default_5.jpg`

3. Recommended image specifications:
   - Format: JPG or PNG
   - Resolution: 1920x1080 or similar (16:9 aspect ratio)
   - File size: Keep under 500KB each for app size
   - Content: Smart home themed, dark/modern aesthetic

## Where to Find Images

You can use free stock images from:
- Unsplash (https://unsplash.com) - search for "smart home", "modern interior", "dark room"
- Pexels (https://pexels.com) - search for similar terms
- Pixabay (https://pixabay.com) - free images

## Quick Setup Commands

```cmd
mkdir assets\images\backgrounds
```

Then manually copy your 5 images into that folder and rename them to match the required names.

## Testing

After adding the images:

1. Run `flutter pub get` to refresh assets
2. Hot restart the app (not hot reload)
3. Open any room or home settings
4. Tap the background settings icon
5. You should see a horizontal gallery of 5 default backgrounds
6. Tap any to select it
7. The background should appear immediately

## Custom Upload (Optional)

The "Upload Custom" button still works if you have Supabase storage configured:

1. Create a bucket named `background-images` in Supabase Storage
2. Make it public
3. Users can then upload custom images

If the bucket doesn't exist, users can still use the default backgrounds without any errors.

## Benefits

- No Supabase storage setup required
- Works offline
- Instant loading (no network delay)
- Consistent experience for all users
- Smaller app size than storing in database
- Users can still upload custom images if they want
