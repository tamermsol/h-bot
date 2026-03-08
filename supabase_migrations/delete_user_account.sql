-- Migration: Add function to delete user account
-- This function allows users to delete their own account and all associated data

-- Create a function that deletes the user's profile and all related data
-- The auth.users record will be handled by Supabase's built-in deletion
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
  -- This includes device_channels (cascade), shutter_states (cascade), etc.
  FOR device_record IN 
    SELECT id FROM devices WHERE owner_user_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting device: %', device_record.id;
    DELETE FROM devices WHERE id = device_record.id;
  END LOOP;
  
  -- Step 3: Delete all homes owned by the user
  -- This will cascade to rooms, scenes, automations, etc.
  FOR home_record IN 
    SELECT id FROM homes WHERE owner_id = v_user_id
  LOOP
    RAISE NOTICE 'Deleting home: %', home_record.id;
    
    -- Delete scenes in this home
    DELETE FROM scenes WHERE home_id = home_record.id;
    
    -- Delete rooms in this home
    DELETE FROM rooms WHERE home_id = home_record.id;
    
    -- Delete the home
    DELETE FROM homes WHERE id = home_record.id;
  END LOOP;
  
  -- Step 4: Delete wifi profiles (if table exists)
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
  -- This requires the function to be SECURITY DEFINER
  DELETE FROM auth.users WHERE id = v_user_id;
  
  RAISE NOTICE 'Account deletion completed for user: %', v_user_id;
  
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account() TO authenticated;

-- Add comment
COMMENT ON FUNCTION delete_user_account() IS 'Allows authenticated users to delete their own account and all associated data including devices, homes, rooms, scenes, scene runs, and wifi profiles';
