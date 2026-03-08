-- FIX: Allow users to add themselves to shared_devices (instant sharing)
-- This fixes the RLS error when scanning QR codes

DROP POLICY IF EXISTS "Users can add shared devices" ON shared_devices;

CREATE POLICY "Users can add shared devices"
    ON shared_devices FOR INSERT
    WITH CHECK (auth.uid() = shared_with_id);

COMMENT ON POLICY "Users can add shared devices" ON shared_devices IS 'Allow users to add themselves as recipients of shared devices (instant sharing via QR code)';
