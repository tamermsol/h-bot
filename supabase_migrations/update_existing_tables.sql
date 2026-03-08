-- Update Existing Device Sharing Tables
-- Run this if you already have the tables but need to fix the QR code function

-- Fix the generate_invitation_code function to generate exactly 32 characters
CREATE OR REPLACE FUNCTION generate_invitation_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate exactly 32 character random code using hex encoding
        -- 16 bytes = 32 hex characters
        code := encode(gen_random_bytes(16), 'hex');
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM device_share_invitations WHERE invitation_code = code) INTO exists;
        
        EXIT WHEN NOT exists;
    END LOOP;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test it (should return 32)
SELECT length(generate_invitation_code()) AS code_length;

-- Success message
SELECT 'QR code function updated successfully! Restart your app now.' AS status;
