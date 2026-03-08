# Run Database Migration - Step by Step

## The Problem

Your app shows this error:
```
Failed to update background: Could not find the 'background_image_url' column
```

This means the database column doesn't exist yet. You need to run a SQL migration to add it.

## The Solution (5 Minutes)

### Step 1: Open Supabase SQL Editor

**Option A: Use the batch file**
```
Double-click: run_migration_now.bat
```

**Option B: Manual**
1. Go to: https://supabase.com/dashboard
2. Click on your project: `mvmvqycvorstsftcldzs`
3. Click "SQL Editor" in the left sidebar

### Step 2: Create New Query

In the SQL Editor:
1. Click the "New Query" button (top right)
2. You'll see an empty SQL editor

### Step 3: Copy the SQL

Open the file: `run_this_migration.sql`

Copy ALL the SQL code (everything in the file)

**The SQL adds these columns:**
- `background_image_url` to `rooms` table
- `background_image_url` to `homes` table

### Step 4: Paste and Run

1. Paste the SQL into the editor
2. Click "Run" button (or press Ctrl+Enter)
3. Wait for the query to complete

### Step 5: Verify Success

You should see output like:
```
NOTICE: Added background_image_url column to rooms table
NOTICE: Added background_image_url column to homes table

table_name | column_name           | data_type
-----------|-----------------------|----------
rooms      | background_image_url  | text
homes      | background_image_url  | text
```

If you see 2 rows in the result, it worked! ✅

### Step 6: Test in App

1. Close and restart your app on the phone
2. Go to any room
3. Tap settings → Background Image
4. Try selecting a background
5. The error should be gone! ✅

## Troubleshooting

### "Column already exists" error

This is OK! It means the column was already added. The migration is safe to run multiple times.

### No output / No rows returned

This might mean:
- The tables don't exist (unlikely)
- You're in the wrong project
- The SQL didn't run

Try running `verify_migration.sql` to check if columns exist.

### Still seeing the error in app

1. Make sure you ran the SQL successfully
2. Make sure you see 2 rows in the output
3. Completely close and restart your app
4. If still failing, check the error message carefully

## Alternative: Run via Supabase Dashboard

If SQL Editor doesn't work:

1. Go to: https://supabase.com/dashboard/project/mvmvqycvorstsftcldzs/editor
2. Click on "rooms" table
3. Click "Add Column" button
4. Column name: `background_image_url`
5. Type: `text`
6. Nullable: Yes
7. Click "Save"
8. Repeat for "homes" table

## Verification

After running the migration, run this SQL to verify:

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name IN ('rooms', 'homes')
  AND column_name = 'background_image_url';
```

You should see 2 rows.

## What This Does

The migration adds a new column to store the background image URL:

**Before:**
```
rooms table:
- id
- home_id
- name
- sort_order
- created_at
- updated_at
```

**After:**
```
rooms table:
- id
- home_id
- name
- sort_order
- background_image_url  ← NEW!
- created_at
- updated_at
```

Same for `homes` table.

## Next Steps

After the migration succeeds:

1. ✅ Run: `setup_backgrounds.bat` (downloads default images)
2. ✅ Run: `flutter pub get`
3. ✅ Hot restart your app
4. ✅ Test background selection

## Files You Need

- `run_migration_now.bat` - Opens SQL Editor with instructions
- `run_this_migration.sql` - The SQL to run
- `verify_migration.sql` - Check if it worked

## Summary

1. Open Supabase SQL Editor
2. Copy SQL from `run_this_migration.sql`
3. Paste and run
4. See 2 rows in output
5. Restart app
6. Error should be gone!

**Time needed:** 5 minutes
**Difficulty:** Easy
**Risk:** None (safe to run multiple times)
