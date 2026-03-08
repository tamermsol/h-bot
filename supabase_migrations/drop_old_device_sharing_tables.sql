-- Drop Old Device Sharing Tables
-- Run this ONLY if you already ran the old migration with wrong foreign keys
-- If this is your first time, skip this and run device_sharing_system.sql directly

-- Drop tables in correct order (child tables first)
DROP TABLE IF EXISTS shared_devices CASCADE;
DROP TABLE IF EXISTS device_share_requests CASCADE;
DROP TABLE IF EXISTS device_share_invitations CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS cleanup_expired_invitations();
DROP FUNCTION IF EXISTS generate_invitation_code();

-- Confirmation message
SELECT 'Old device sharing tables dropped successfully. Now run device_sharing_system.sql' AS status;
