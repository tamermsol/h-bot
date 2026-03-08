-- =====================================================
-- Update Existing Channels with Default Type
-- Run this AFTER add_channel_type_simple.sql
-- =====================================================

-- Check current state
SELECT 
  device_id,
  channel_no,
  label,
  channel_type
FROM device_channels
ORDER BY device_id, channel_no
LIMIT 10;

-- Update any NULL channel_type values to 'light'
UPDATE device_channels
SET channel_type = 'light'
WHERE channel_type IS NULL;

-- Verify the update
SELECT 
  COUNT(*) as total_channels,
  COUNT(CASE WHEN channel_type = 'light' THEN 1 END) as light_channels,
  COUNT(CASE WHEN channel_type = 'switch' THEN 1 END) as switch_channels,
  COUNT(CASE WHEN channel_type IS NULL THEN 1 END) as null_channels
FROM device_channels;

-- Show sample of updated channels
SELECT 
  device_id,
  channel_no,
  label,
  channel_type
FROM device_channels
ORDER BY device_id, channel_no
LIMIT 10;
