# Delete Account - "user_id is ambiguous" Error Fix

## Error Message
```
Database error: column reference "user_id" is ambiguous
```

## What Caused This
The variable name `user_id` in the PostgreSQL function was conflicting with column names in the database tables. When the function tried to use `user_id`, PostgreSQL didn't know if it meant:
- The variable `user_id` (the user being deleted)
- The column `wifi_profiles.user_id`
- Or other `user_id` columns in other tables

## The Fix
Changed the variable name from `user_id` to `v_user_id` (with `v_` prefix meaning "variable") to avoid any ambiguity.

## How to Apply

**Run this updated SQL in Supabase Dashboard → SQL Editor:**

```sql
-- Migration: Add function to delete user account
-- This function allows users to delete their own account and all associated data

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;  -- Changed from user_id to v_user_id
  home_record RECORD;
  device_record RECORD;
BEGIN
  -- Get the current user's ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  RAISE NOTICE 'Starting account deletion for user: %', v_user_id;
  
  -- Step 1: Delete all devices owned by the user
  FOR device_record IN 
    SELECT id FROM devices WHERE owner_user_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting device: %', device_record.id;
    DELETE FROM devices WHERE id = device_record.id;
  END LOOP;
  
  -- Step 2: Delete all homes owned by the user
  FOR home_record IN 
    SELECT id FROM homes WHERE owner_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting home: %', home_record.id;
    
    DELETE FROM scenes WHERE home_id = home_record.id;
    DELETE FROM rooms WHERE home_id = home_record.id;
    DELETE FROM homes WHERE id = home_record.id;
  END LOOP;
  
  -- Step 3: Delete wifi profiles
  BEGIN
    DELETE FROM wifi_profiles WHERE wifi_profiles.user_id = v_user_id;
  EXCEPTION
    WHEN undefined_table THEN
      RAISE NOTICE 'wifi_profiles table does not exist, skipping';
    WHEN undefined_column THEN
      RAISE NOTICE 'wifi_profiles.user_id column does not exist, skipping';
  END;
  
  -- Step 4: Delete user's profile
  DELETE FROM profiles WHERE id = v_user_id;
  
  -- Step 5: Delete the user from auth.users
  DELETE FROM auth.users WHERE id = v_user_id;
  
  RAISE NOTICE 'Account deletion completed for user: %', v_user_id;
  
END;
$$;

GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;
```

## What Changed

**Before:**
```sql
DECLARE
  user_id uuid;  -- ❌ Ambiguous with column names
BEGIN
  user_id := auth.uid();
  DELETE FROM wifi_profiles WHERE user_id = user_id;  -- ❌ Which user_id?
```

**After:**
```sql
DECLARE
  v_user_id uuid;  -- ✅ Clear it's a variable
BEGIN
  v_user_id := auth.uid();
  DELETE FROM wifi_profiles WHERE wifi_profiles.user_id = v_user_id;  -- ✅ Clear distinction
```

## Testing

After applying the fix:
1. Try to delete a test account
2. Should complete without the "ambiguous" error
3. All user data should be deleted

## Status
✅ **FIXED** - Variable naming conflict resolved
