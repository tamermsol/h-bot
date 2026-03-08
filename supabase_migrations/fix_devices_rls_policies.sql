-- Fix RLS policies for devices and devices_with_channels view
-- This ensures users can see devices in their homes

-- First, check if RLS is enabled on devices table
-- If not enabled, enable it
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view devices in their homes" ON devices;
DROP POLICY IF EXISTS "Users can view their own devices" ON devices;
DROP POLICY IF EXISTS "Users can insert devices" ON devices;
DROP POLICY IF EXISTS "Users can update their devices" ON devices;
DROP POLICY IF EXISTS "Users can delete their devices" ON devices;

-- Create comprehensive RLS policies for devices

-- 1. SELECT policy: Users can view devices in homes they are members of
CREATE POLICY "Users can view devices in their homes"
ON devices
FOR SELECT
TO authenticated
USING (
    -- User owns the device
    owner_user_id = auth.uid()
    OR
    -- User is a member of the home containing the device
    EXISTS (
        SELECT 1 FROM home_members hm
        WHERE hm.home_id = devices.home_id
        AND hm.user_id = auth.uid()
    )
    OR
    -- User owns the home containing the device
    EXISTS (
        SELECT 1 FROM homes h
        WHERE h.id = devices.home_id
        AND h.owner_id = auth.uid()
    )
);

-- 2. INSERT policy: Users can insert devices into their homes
CREATE POLICY "Users can insert devices"
ON devices
FOR INSERT
TO authenticated
WITH CHECK (
    -- User owns the device
    owner_user_id = auth.uid()
    OR
    -- User is a member of the home
    EXISTS (
        SELECT 1 FROM home_members hm
        WHERE hm.home_id = devices.home_id
        AND hm.user_id = auth.uid()
    )
    OR
    -- User owns the home
    EXISTS (
        SELECT 1 FROM homes h
        WHERE h.id = devices.home_id
        AND h.owner_id = auth.uid()
    )
);

-- 3. UPDATE policy: Users can update their devices
CREATE POLICY "Users can update their devices"
ON devices
FOR UPDATE
TO authenticated
USING (
    -- User owns the device
    owner_user_id = auth.uid()
    OR
    -- User is a member of the home
    EXISTS (
        SELECT 1 FROM home_members hm
        WHERE hm.home_id = devices.home_id
        AND hm.user_id = auth.uid()
    )
    OR
    -- User owns the home
    EXISTS (
        SELECT 1 FROM homes h
        WHERE h.id = devices.home_id
        AND h.owner_id = auth.uid()
    )
)
WITH CHECK (
    -- User owns the device
    owner_user_id = auth.uid()
    OR
    -- User is a member of the home
    EXISTS (
        SELECT 1 FROM home_members hm
        WHERE hm.home_id = devices.home_id
        AND hm.user_id = auth.uid()
    )
    OR
    -- User owns the home
    EXISTS (
        SELECT 1 FROM homes h
        WHERE h.id = devices.home_id
        AND h.owner_id = auth.uid()
    )
);

-- 4. DELETE policy: Users can delete their devices
CREATE POLICY "Users can delete their devices"
ON devices
FOR DELETE
TO authenticated
USING (
    -- User owns the device
    owner_user_id = auth.uid()
    OR
    -- User owns the home
    EXISTS (
        SELECT 1 FROM homes h
        WHERE h.id = devices.home_id
        AND h.owner_id = auth.uid()
    )
);

-- Grant necessary permissions
GRANT SELECT ON devices TO authenticated;
GRANT INSERT ON devices TO authenticated;
GRANT UPDATE ON devices TO authenticated;
GRANT DELETE ON devices TO authenticated;

-- Ensure the view has proper permissions
GRANT SELECT ON devices_with_channels TO authenticated;

-- Add helpful comment
COMMENT ON POLICY "Users can view devices in their homes" ON devices IS 
'Allows users to view devices they own or devices in homes they are members of';
