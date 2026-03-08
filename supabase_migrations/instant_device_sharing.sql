-- Instant Device Sharing Migration
-- This enables instant sharing without approval - scanning QR immediately grants access

-- Update RLS policy for devices to allow shared users to view devices
-- Drop existing policy if it exists
DROP POLICY IF EXISTS "Users can view shared devices" ON devices;

-- Create new policy to allow viewing devices shared with the user
CREATE POLICY "Users can view shared devices"
    ON devices FOR SELECT
    USING (
        id IN (
            SELECT device_id 
            FROM shared_devices 
            WHERE shared_with_id = auth.uid()
        )
    );

-- Update RLS policy for devices_with_channels view
-- Note: Views inherit RLS from base tables, but we need to ensure the join works
-- The devices_with_channels view should already work with the devices table policy

-- Update RLS policy for device_state to allow shared users to view state
DROP POLICY IF EXISTS "Users can view state of shared devices" ON device_state;

CREATE POLICY "Users can view state of shared devices"
    ON device_state FOR SELECT
    USING (
        device_id IN (
            SELECT device_id 
            FROM shared_devices 
            WHERE shared_with_id = auth.uid()
        )
    );

-- Update RLS policy for device_channels to allow shared users to view channels
DROP POLICY IF EXISTS "Users can view channels of shared devices" ON device_channels;

CREATE POLICY "Users can view channels of shared devices"
    ON device_channels FOR SELECT
    USING (
        device_id IN (
            SELECT device_id 
            FROM shared_devices 
            WHERE shared_with_id = auth.uid()
        )
    );

-- Allow shared users with 'control' permission to update device state
DROP POLICY IF EXISTS "Users can control shared devices" ON device_state;

CREATE POLICY "Users can control shared devices"
    ON device_state FOR UPDATE
    USING (
        device_id IN (
            SELECT device_id 
            FROM shared_devices 
            WHERE shared_with_id = auth.uid() 
            AND permission_level = 'control'
        )
    );

-- Comments for documentation
COMMENT ON POLICY "Users can view shared devices" ON devices IS 'Allow users to view devices shared with them';
COMMENT ON POLICY "Users can view state of shared devices" ON device_state IS 'Allow users to view state of devices shared with them';
COMMENT ON POLICY "Users can view channels of shared devices" ON device_channels IS 'Allow users to view channels of devices shared with them';
COMMENT ON POLICY "Users can control shared devices" ON device_state IS 'Allow users with control permission to update state of shared devices';

-- CRITICAL FIX: Allow users to add themselves to shared_devices (instant sharing)
-- This policy allows the recipient to insert a row where they are the shared_with_id
DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);

COMMENT ON POLICY "Users can add shared devices" ON shared_devices IS 'Allow users to add themselves as recipients of shared devices (instant sharing via QR code)';
