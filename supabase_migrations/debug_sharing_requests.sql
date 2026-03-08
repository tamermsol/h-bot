-- Debug Device Sharing Requests
-- Run this to see what's in the database

-- Check all share requests
SELECT 
    id,
    device_id,
    owner_id,
    requester_id,
    requester_email,
    status,
    requested_at
FROM device_share_requests
ORDER BY requested_at DESC;

-- Check all invitations
SELECT 
    id,
    device_id,
    owner_id,
    invitation_code,
    expires_at,
    created_at
FROM device_share_invitations
ORDER BY created_at DESC;

-- Check all shared devices
SELECT 
    id,
    device_id,
    owner_id,
    shared_with_id,
    permission_level,
    shared_at
FROM shared_devices
ORDER BY shared_at DESC;

-- Check if there are any requests for a specific device
-- Replace 'YOUR_DEVICE_ID' with actual device ID
-- SELECT * FROM device_share_requests WHERE device_id = 'YOUR_DEVICE_ID';
