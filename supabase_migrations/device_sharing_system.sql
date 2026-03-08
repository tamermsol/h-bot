-- Device Sharing System Migration
-- This enables users to share devices with other users via QR codes

-- Table for sharing invitations (temporary, expires after 24 hours)
CREATE TABLE IF NOT EXISTS device_share_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    invitation_code TEXT NOT NULL UNIQUE, -- Used in QR code
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Indexes for performance
    CONSTRAINT invitation_code_length CHECK (char_length(invitation_code) = 32)
);

CREATE INDEX IF NOT EXISTS idx_share_invitations_code ON device_share_invitations(invitation_code);
CREATE INDEX IF NOT EXISTS idx_share_invitations_expires ON device_share_invitations(expires_at);
CREATE INDEX IF NOT EXISTS idx_share_invitations_device ON device_share_invitations(device_id);

-- Table for sharing requests (pending approval)
CREATE TABLE IF NOT EXISTS device_share_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    requester_email TEXT NOT NULL,
    requester_name TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    
    -- Prevent duplicate requests
    UNIQUE(device_id, requester_id)
);

CREATE INDEX IF NOT EXISTS idx_share_requests_owner ON device_share_requests(owner_id, status);
CREATE INDEX IF NOT EXISTS idx_share_requests_requester ON device_share_requests(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_share_requests_device ON device_share_requests(device_id);

-- Table for approved shared devices
CREATE TABLE IF NOT EXISTS shared_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    shared_with_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    permission_level TEXT NOT NULL DEFAULT 'view' CHECK (permission_level IN ('view', 'control')),
    shared_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Prevent duplicate shares
    UNIQUE(device_id, shared_with_id)
);

CREATE INDEX IF NOT EXISTS idx_shared_devices_user ON shared_devices(shared_with_id);
CREATE INDEX IF NOT EXISTS idx_shared_devices_owner ON shared_devices(owner_id);
CREATE INDEX IF NOT EXISTS idx_shared_devices_device ON shared_devices(device_id);

-- Enable RLS
ALTER TABLE device_share_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_share_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for device_share_invitations
CREATE POLICY "Users can create invitations for their devices"
    ON device_share_invitations FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can view their own invitations"
    ON device_share_invitations FOR SELECT
    USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete their own invitations"
    ON device_share_invitations FOR DELETE
    USING (auth.uid() = owner_id);

CREATE POLICY "Anyone can view valid invitations by code"
    ON device_share_invitations FOR SELECT
    USING (expires_at > NOW());

-- RLS Policies for device_share_requests
CREATE POLICY "Users can create share requests"
    ON device_share_requests FOR INSERT
    WITH CHECK (auth.uid() = requester_id);

CREATE POLICY "Owners can view requests for their devices"
    ON device_share_requests FOR SELECT
    USING (auth.uid() = owner_id);

CREATE POLICY "Requesters can view their own requests"
    ON device_share_requests FOR SELECT
    USING (auth.uid() = requester_id);

CREATE POLICY "Owners can update request status"
    ON device_share_requests FOR UPDATE
    USING (auth.uid() = owner_id);

-- RLS Policies for shared_devices
CREATE POLICY "Owners can manage shared devices"
    ON shared_devices FOR ALL
    USING (auth.uid() = owner_id);

CREATE POLICY "Shared users can view their shared devices"
    ON shared_devices FOR SELECT
    USING (auth.uid() = shared_with_id);

-- Function to clean up expired invitations
CREATE OR REPLACE FUNCTION cleanup_expired_invitations()
RETURNS void AS $$
BEGIN
    DELETE FROM device_share_invitations
    WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate unique invitation code
CREATE OR REPLACE FUNCTION generate_invitation_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate 32 character random code
        code := encode(gen_random_bytes(24), 'base64');
        code := replace(replace(replace(code, '+', ''), '/', ''), '=', '');
        code := substring(code, 1, 32);
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM device_share_invitations WHERE invitation_code = code) INTO exists;
        
        EXIT WHEN NOT exists;
    END LOOP;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments for documentation
COMMENT ON TABLE device_share_invitations IS 'Temporary invitations for sharing devices via QR codes';
COMMENT ON TABLE device_share_requests IS 'Pending requests from users who scanned QR codes';
COMMENT ON TABLE shared_devices IS 'Approved device shares with access permissions';
