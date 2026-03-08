# Fix Background Image Errors - Step by Step

## Current Errors

❌ "Failed to update background: Could not find the 'background_image_url' column"
⚠️ "Failed to upload image: Bucket not found" (This is OK - see below)

## Fix in 3 Steps (5 minutes)

### Step 1: Add Database Column (REQUIRED)

This fixes the "column not found" error.

**Quick Method:**

1. Double-click: `open_supabase_sql_editor.bat`
2. Your Supabase SQL Editor will open in browser
3. Click "New Query"
4. Open file: `run_this_migration.sql`
5. Copy all the SQL code
6. Paste into SQL Editor
7. Click "Run" (or press Ctrl+Enter)
8. Wait for "Success" message

**Manual Method:**

1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click "SQL Editor" in left sidebar
4. Click "New Query"
5. Copy contents of `run_this_migration.sql`
6. Paste and click "Run"

**Verify it worked:**

You should see this output:
```
table_name | column_name           | data_type
-----------|-----------------------|----------
rooms      | background_image_url  | text
homes      | background_image_url  | text
```

### Step 2: Add Default Images (REQUIRED)

This adds 5 default background images to your app.

1. Double-click: `setup_backgrounds.bat`
2. Wait for download to complete
3. You should see: "Downloaded 5 new image(s)"

### Step 3: Update Flutter (REQUIRED)

```cmd
flutter pub get
```

Then hot restart your app (not hot reload).

## Test It

1. Open your app
2. Go to any room
3. Tap the settings icon (gear)
4. Tap "Background Image"
5. You should see:
   - ✅ Gallery of 5 default backgrounds
   - ✅ Tap any to select
   - ✅ Background appears on screen
   - ✅ No "column not found" error

## About "Bucket not found" Error

This error is **EXPECTED** and **OK**. Here's why:

- Default backgrounds work without Supabase storage
- Users can select from 5 built-in backgrounds
- The error only shows when trying to upload a custom image
- Custom uploads are optional

### To Enable Custom Uploads (Optional)

Only do this if you want users to upload their own images:

1. Go to Supabase Dashboard → Storage
2. Click "Create a new bucket"
3. Name: `background-images`
4. Make it public
5. Add policies:
   - Public read access
   - Authenticated users can upload

## Troubleshooting

### "Column not found" error still shows

- Make sure you ran the SQL migration (Step 1)
- Check the SQL output showed 2 rows
- Try restarting your app

### Gallery shows gray boxes

- Make sure you ran `setup_backgrounds.bat` (Step 2)
- Check that 5 images exist in `assets/images/backgrounds/`
- Run: `flutter clean && flutter pub get`
- Hot restart (not hot reload)

### Background doesn't appear on screen

- Make sure you hot restarted (not hot reload)
- Check console for errors
- Try selecting a different background

## Quick Checklist

- [ ] Step 1: Run SQL migration
- [ ] Step 2: Run `setup_backgrounds.bat`
- [ ] Step 3: Run `flutter pub get`
- [ ] Hot restart app
- [ ] Test: Select a background
- [ ] Verify: Background appears on screen

## Files to Use

1. `open_supabase_sql_editor.bat` - Opens SQL Editor
2. `run_this_migration.sql` - SQL to run
3. `setup_backgrounds.bat` - Downloads images
4. `FIX_BACKGROUND_ERRORS.md` - Detailed explanation

## Summary

The main issue is the missing database column. Run the SQL migration and you're done!

The "bucket not found" error is expected and doesn't need to be fixed unless you want custom uploads.
