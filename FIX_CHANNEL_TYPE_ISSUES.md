# Channel Type Issues - FIXED

## Issues Found

1. ❌ Database migration not applied - column `channel_type` doesn't exist
2. ❌ Function name mismatch - needs `public.` prefix
3. ❌ Default was 'switch' but you wanted 'light'

## Fixes Applied

### 1. Updated Migration Script ✅
- Changed default from 'switch' to 'light'
- Fixed function name to `public.update_channel_type`
- Created simplified version: `add_channel_type_simple.sql`

### 2. Updated Dart Code ✅
- Changed default in `DeviceChannel` model to 'light'
- Changed default in `DeviceWithChannels.getChannelType()` to 'light'
- Changed default in UI components to 'light'

### 3. Updated Documentation ✅
- All docs now reflect 'light' as default
- Updated test scenarios
- Updated feature descriptions

## How to Fix Your Database

### Option 1: Run Simple Migration (RECOMMENDED)

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `supabase_migrations/add_channel_type_simple.sql`
3. Paste and click "Run"
4. Verify you see success message

### Option 2: Run via Supabase CLI

```bash
supabase db push
```

## After Running Migration

1. **Restart your Flutter app**
2. **Test the feature:**
   - Open any relay device
   - Long-press on a channel
   - Select "Switch" (to change from default 'light')
   - Verify icon changes from 💡 to ⚡
   - Verify no error messages

## What Changed

### Before (Broken)
```
❌ No channel_type column in database
❌ Function not found error
❌ Default was 'switch'
```

### After (Fixed)
```
✅ channel_type column exists (default: 'light')
✅ Function public.update_channel_type() exists
✅ Default is 'light' (can be changed to 'switch')
```

## Expected Behavior

### Default State
- All channels show 💡 (lightbulb icon)
- Channel type is 'light'

### After Changing to Switch
- Channel shows ⚡ (power icon)
- Channel type is 'switch'

### After Changing Back to Light
- Channel shows 💡 (lightbulb icon)
- Channel type is 'light'

## Files Changed

### Migration Files
- ✅ `supabase_migrations/add_channel_type.sql` (updated)
- ✅ `supabase_migrations/add_channel_type_simple.sql` (new, easier to use)
- ✅ `APPLY_CHANNEL_TYPE_MIGRATION.md` (new, step-by-step guide)

### Dart Code
- ✅ `lib/models/device_channel.dart` (default changed to 'light')
- ✅ `lib/screens/device_control_screen.dart` (default changed to 'light')

### Documentation
- ✅ `CHANNEL_TYPE_FEATURE.md` (updated)
- ✅ `CHANNEL_TYPE_TESTING_GUIDE.md` (updated)
- ✅ `FIX_CHANNEL_TYPE_ISSUES.md` (this file)

## Verification Steps

After running the migration, verify in Supabase SQL Editor:

```sql
-- Check column exists with correct default
SELECT 
  column_name, 
  data_type, 
  column_default 
FROM information_schema.columns 
WHERE table_name = 'device_channels' 
  AND column_name = 'channel_type';

-- Should show: channel_type | text | 'light'::text

-- Check function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'update_channel_type';

-- Should show: update_channel_type

-- Check existing channels (if any)
SELECT device_id, channel_no, label, channel_type 
FROM device_channels 
LIMIT 5;

-- All should show channel_type = 'light'
```

## Troubleshooting

### Still Getting Error?

1. **Check if migration ran:**
   ```sql
   SELECT column_name FROM information_schema.columns 
   WHERE table_name = 'device_channels' AND column_name = 'channel_type';
   ```
   - If empty: Migration didn't run, run it again
   - If shows result: Migration ran successfully

2. **Check function exists:**
   ```sql
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_name = 'update_channel_type';
   ```
   - If empty: Function not created, run migration again
   - If shows result: Function exists

3. **Restart Flutter app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Error: "column already exists"

This means you ran the migration before. Check if it has the correct default:

```sql
SELECT column_default FROM information_schema.columns 
WHERE table_name = 'device_channels' AND column_name = 'channel_type';
```

If it shows `'switch'::text`, update it:

```sql
ALTER TABLE device_channels 
ALTER COLUMN channel_type SET DEFAULT 'light';

-- Update existing rows
UPDATE device_channels SET channel_type = 'light';
```

## Summary

✅ **Migration script fixed** - Now uses 'light' as default  
✅ **Function name fixed** - Now uses `public.update_channel_type`  
✅ **Dart code updated** - All defaults changed to 'light'  
✅ **Documentation updated** - All docs reflect 'light' as default  
✅ **Simple migration created** - Easy to run in Supabase SQL Editor  

**Next Step:** Run the migration in Supabase SQL Editor using `add_channel_type_simple.sql`
