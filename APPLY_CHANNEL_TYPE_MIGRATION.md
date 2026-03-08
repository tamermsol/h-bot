# How to Apply Channel Type Migration

## Step-by-Step Instructions

### 1. Open Supabase Dashboard
1. Go to your Supabase project dashboard
2. Click on "SQL Editor" in the left sidebar

### 2. Run the Migration
1. Click "New Query" button
2. Copy the entire contents of `supabase_migrations/add_channel_type_simple.sql`
3. Paste it into the SQL editor
4. Click "Run" button (or press Ctrl+Enter)

### 3. Verify Success
You should see output like:
```
Success. No rows returned
```

And at the end, you should see a table showing:
```
column_name   | data_type | column_default
--------------+-----------+----------------
channel_type  | text      | 'light'::text
```

### 4. Test in Your App
1. Restart your Flutter app
2. Open any relay device
3. Long-press on a channel
4. Try changing between Light and Switch
5. Verify the icon changes (💡 for light, ⚡ for switch)

## Troubleshooting

### Error: "column already exists"
If you see this error, it means the column was partially added. Run this to fix:
```sql
-- Remove the column and start fresh
ALTER TABLE device_channels DROP COLUMN IF EXISTS channel_type;

-- Then run the full migration again
```

### Error: "function already exists"
This is OK - it means the function was created. The migration will replace it.

### Error: "view already exists"
This is OK - the migration drops and recreates the view.

### Error: "permission denied"
Make sure you're logged in as the database owner or have sufficient permissions.

## What This Migration Does

1. ✅ Adds `channel_type` column to `device_channels` table (default: 'light')
2. ✅ Adds constraint to ensure only 'light' or 'switch' values
3. ✅ Creates index for performance
4. ✅ Creates `update_channel_type()` function
5. ✅ Updates `devices_with_channels` view to include channel types
6. ✅ Grants proper permissions

## After Migration

All existing channels will default to 'light' type. Users can change them to 'switch' if needed.

## Rollback (if needed)

If you need to undo the migration:
```sql
-- Remove the column
ALTER TABLE device_channels DROP COLUMN IF EXISTS channel_type;

-- Drop the function
DROP FUNCTION IF EXISTS public.update_channel_type;

-- Recreate the view without channel_type
-- (Use your original view definition)
```
