# Delete Account - Scene Runs Foreign Key Fix

## Error
```
Database error: update or delete on table "users" violates foreign key constraint "scene_runs_user_id_fkey" on table "scene_runs"
```

## Root Cause
The `scene_runs` table has a foreign key reference to the `users` table (`user_id`), but the delete function wasn't deleting scene runs before trying to delete the user. This caused a foreign key constraint violation.

## The Fix
Updated the `delete_user_account()` function to delete `scene_runs` records FIRST, before deleting anything else.

## Updated Deletion Order

1. ✅ **Scene runs** (NEW - added first)
2. ✅ Devices (with channels and shutter states)
3. ✅ Homes (with rooms and scenes)
4. ✅ WiFi profiles
5. ✅ User profile
6. ✅ User auth record

## How to Apply

**Run this SQL in Supabase Dashboard → SQL Editor:**

```sql
-- Migration: Add function to delete user account
-- This function allows users to delete their own account and all associated data

CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
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
  
  -- Step 1: Delete scene runs (if table exists)
  BEGIN
    DELETE FROM scene_runs WHERE user_id = v_user_id;
    RAISE NOTICE 'Deleted scene runs for user';
  EXCEPTION
    WHEN undefined_table THEN
      RAISE NOTICE 'scene_runs table does not exist, skipping';
  END;
  
  -- Step 2: Delete all devices owned by the user
  FOR device_record IN 
    SELECT id FROM devices WHERE owner_user_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting device: %', device_record.id;
    DELETE FROM devices WHERE id = device_record.id;
  END LOOP;
  
  -- Step 3: Delete all homes owned by the user
  FOR home_record IN 
    SELECT id FROM homes WHERE owner_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting home: %', home_record.id;
    
    DELETE FROM scenes WHERE home_id = home_record.id;
    DELETE FROM rooms WHERE home_id = home_record.id;
    DELETE FROM homes WHERE id = home_record.id;
  END LOOP;
  
  -- Step 4: Delete wifi profiles
  BEGIN
    DELETE FROM wifi_profiles WHERE wifi_profiles.user_id = v_user_id;
  EXCEPTION
    WHEN undefined_table THEN
      RAISE NOTICE 'wifi_profiles table does not exist, skipping';
    WHEN undefined_column THEN
      RAISE NOTICE 'wifi_profiles.user_id column does not exist, skipping';
  END;
  
  -- Step 5: Delete user's profile
  DELETE FROM profiles WHERE id = v_user_id;
  
  -- Step 6: Delete the user from auth.users
  DELETE FROM auth.users WHERE id = v_user_id;
  
  RAISE NOTICE 'Account deletion completed for user: %', v_user_id;
  
END;
$$;

GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;
```

## What Changed

**Added at the beginning:**
```sql
-- Step 1: Delete scene runs (if table exists)
BEGIN
  DELETE FROM scene_runs WHERE user_id = v_user_id;
  RAISE NOTICE 'Deleted scene runs for user';
EXCEPTION
  WHEN undefined_table THEN
    RAISE NOTICE 'scene_runs table does not exist, skipping';
END;
```

This deletes all scene run history for the user before attempting to delete the user record, preventing the foreign key constraint violation.

## Why This Happened

The `scene_runs` table tracks when scenes are executed and by which user. It has a foreign key to `auth.users(id)`. When we tried to delete the user without first deleting their scene runs, PostgreSQL prevented the deletion to maintain referential integrity.

## Testing

After applying the fix:
1. Try to delete a test account
2. Should complete without the foreign key error
3. All user data including scene runs should be deleted

## Status
✅ **FIXED** - Scene runs are now deleted before user deletion
