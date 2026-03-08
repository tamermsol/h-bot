# Fix Background Image Errors

## Errors Shown

1. **"Failed to upload image: Bucket not found"**
   - Supabase storage bucket doesn't exist
   - This is expected and OK - default backgrounds still work

2. **"Failed to update background: Could not find the 'background_image_url' column"**
   - Database migration hasn't been run yet
   - Need to add the column to the database

## Solution

### Step 1: Run Database Migration

You need to run the SQL migration to add the `background_image_url` column to your database.

**Option A: Using Supabase Dashboard (Recommended)**

1. Go to your Supabase Dashboard
2. Click on "SQL Editor" in the left sidebar
3. Click "New Query"
4. Copy and paste the contents of `supabase_migrations/add_background_images.sql`
5. Click "Run" or press Ctrl+Enter
6. You should see "Success. No rows returned"

**Option B: Using Supabase CLI**

```cmd
supabase db push
```

Or manually apply the migration:

```cmd
supabase db execute -f supabase_migrations/add_background_images.sql
```

### Step 2: Add Default Background Images

Run this to download default images:

```cmd
setup_backgrounds.bat
```

Then:

```cmd
flutter pub get
```

### Step 3: Test

1. Hot restart your app (not hot reload)
2. Open any room
3. Tap settings → Background Image
4. You should see:
   - Gallery of 5 default backgrounds
   - Tap any to select
   - Background appears on screen
   - No more "column not found" error

## About the "Bucket not found" Error

This error is expected if you haven't created a Supabase storage bucket. It's OK because:

- Default backgrounds work without Supabase storage
- Users can still select from 5 built-in backgrounds
- The error only shows when trying to upload a custom image

### To Enable Custom Uploads (Optional)

If you want users to upload custom images:

1. Go to Supabase Dashboard → Storage
2. Click "Create a new bucket"
3. Name it: `background-images`
4. Make it public:
   - Click on the bucket
   - Click "Policies"
   - Add policy: "Allow public read access"
   - Add policy: "Allow authenticated users to upload"

## Verification

After running the migration, verify it worked:

```sql
-- Run this in Supabase SQL Editor
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'rooms' 
AND column_name = 'background_image_url';

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'homes' 
AND column_name = 'background_image_url';
```

You should see:
```
column_name           | data_type
----------------------|----------
background_image_url  | text
```

## Summary

1. ✅ Run the SQL migration (Step 1)
2. ✅ Add default images (Step 2)
3. ✅ Test the feature (Step 3)
4. ⚠️ "Bucket not found" error is OK (custom uploads are optional)

The main fix is running the database migration to add the `background_image_url` column.
