# Default Background Images

This folder should contain 5 default background images for the app.

## Required Files

Place these 5 images in this folder:

1. `default_1.jpg`
2. `default_2.jpg`
3. `default_3.jpg`
4. `default_4.jpg`
5. `default_5.jpg`

## Quick Setup

From the project root, run:

```cmd
powershell -ExecutionPolicy Bypass -File download_backgrounds.ps1
```

This will automatically download free smart home themed images from Unsplash.

## Manual Setup

If you prefer to use your own images:

1. Find or create 5 images
2. Recommended specs:
   - Format: JPG (smaller file size)
   - Resolution: 1920x1080 or similar
   - File size: Under 500KB each
   - Theme: Smart home, modern interior, dark aesthetic
3. Rename them to match the required filenames above
4. Place them in this folder

## Free Image Sources

- Unsplash: https://unsplash.com (search: "smart home", "modern interior")
- Pexels: https://pexels.com
- Pixabay: https://pixabay.com

## After Adding Images

1. Run: `flutter pub get`
2. Hot restart your app
3. Test the background picker
