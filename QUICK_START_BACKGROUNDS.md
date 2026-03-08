# Quick Start: Default Background Images

## What Changed?

Your app now has default background images built-in! No more Supabase storage errors.

## Setup (2 minutes)

### Option 1: Automatic (Recommended)

Double-click this file:
```
setup_backgrounds.bat
```

It will download 5 free smart home themed images automatically.

### Option 2: Manual

1. Download 5 images you like
2. Rename them: `default_1.jpg`, `default_2.jpg`, `default_3.jpg`, `default_4.jpg`, `default_5.jpg`
3. Put them in: `assets/images/backgrounds/`

## Finish Setup

After adding images:

```cmd
flutter pub get
```

Then hot restart your app (not hot reload).

## How It Works Now

1. Open any room
2. Tap the gear icon (settings)
3. Tap "Background Image"
4. You'll see:
   - **Horizontal gallery** of 5 default backgrounds
   - Tap any to select instantly
   - Selected one has a blue border
   - "Upload Custom" button if you want to upload your own
   - "Remove" button to clear the background

## Benefits

✅ No Supabase storage setup needed
✅ Works offline
✅ Instant selection (no upload wait)
✅ No "bucket not found" errors
✅ Still supports custom uploads (optional)

## Troubleshooting

**Images don't show?**
- Make sure files are named exactly: `default_1.jpg` through `default_5.jpg`
- Make sure they're in: `assets/images/backgrounds/`
- Run: `flutter clean && flutter pub get`
- Do a full restart (not hot reload)

**Want to use custom uploads?**
- Create a Supabase storage bucket named `background-images`
- Make it public
- Users can then upload custom images

## That's It!

Your background image feature is now ready to use with no backend setup required.
