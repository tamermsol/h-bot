# 🚨 URGENT: Fix Background Image Error NOW

## The Error You're Seeing

```
Failed to update background: Could not find the 'background_image_url' column
```

## Quick Fix (2 Minutes)

### Method 1: Use HTML Tool (EASIEST)

1. **Double-click:** `run_migration.html`
2. Browser opens with instructions
3. Click "Open Supabase SQL Editor"
4. Click "Copy SQL to Clipboard"
5. In SQL Editor: Click "New Query"
6. Paste (Ctrl+V) and click "Run"
7. Done! ✅

### Method 2: Use Batch File

1. **Double-click:** `run_migration_now.bat`
2. Follow the instructions shown
3. Copy SQL from `run_this_migration.sql`
4. Paste in SQL Editor and run
5. Done! ✅

### Method 3: Manual

1. Go to: https://supabase.com/dashboard/project/mvmvqycvorstsftcldzs/sql
2. Click "New Query"
3. Copy ALL content from `run_this_migration.sql`
4. Paste and click "Run"
5. Done! ✅

## Verify It Worked

You should see this output:
```
table_name | column_name           | data_type
-----------|-----------------------|----------
rooms      | background_image_url  | text
homes      | background_image_url  | text
```

If you see 2 rows = SUCCESS! ✅

## Test on Phone

1. Close your app completely
2. Restart the app
3. Go to any room
4. Tap settings → Background Image
5. Select a background
6. Error should be GONE! ✅

## Still Not Working?

### Check 1: Did the SQL run successfully?
- Open `verify_migration.sql` in SQL Editor
- Run it
- Should show 2 rows

### Check 2: Did you restart the app?
- Don't just hot reload
- Close app completely
- Restart from scratch

### Check 3: Are you on the right project?
- Project ID: `mvmvqycvorstsftcldzs`
- Check in Supabase dashboard

## Files to Use

| File | Purpose | Action |
|------|---------|--------|
| `run_migration.html` | Interactive guide | Double-click |
| `run_migration_now.bat` | Opens SQL Editor | Double-click |
| `run_this_migration.sql` | SQL to run | Copy & paste |
| `verify_migration.sql` | Check if it worked | Run in SQL Editor |

## What This Does

Adds `background_image_url` column to:
- ✅ `rooms` table
- ✅ `homes` table

This is required for the background image feature to work.

## After Migration

1. Run: `setup_backgrounds.bat`
2. Run: `flutter pub get`
3. Hot restart app
4. Test!

## Time Required

- Migration: 2 minutes
- Testing: 1 minute
- Total: 3 minutes

## Risk Level

✅ SAFE - Can run multiple times without issues

## Summary

1. Open `run_migration.html` in browser
2. Follow the 3 steps
3. Restart app
4. Test on phone
5. Done!

**The error will be fixed after running the SQL migration.**
