-- =====================================================
-- Diagnose Channel Type Issues
-- Run this to see what's in your database
-- =====================================================

-- 1. Check if channel_type column exists
SELECT 
  column_name, 
  data_type, 
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'device_channels' 
  AND column_name = 'channel_type';

-- Expected: channel_type | text | 'light'::text | NO

-- 2. Check actual channel data
SELECT 
  device_id,
  channel_no,
  label,
  label_is_custom,
  channel_type,
  updated_at
FROM device_channels
ORDER BY device_id, channel_no;

-- 3. Check the view output
SELECT 
  id,
  display_name,
  channels,
  channel_labels
FROM devices_with_channels
LIMIT 5;

-- 4. Check a specific device's channel_labels JSON
-- Replace 'YOUR_DEVICE_ID' with an actual device ID
-- SELECT 
--   id,
--   display_name,
--   channel_labels,
--   channel_labels->'1' as channel_1_data,
--   channel_labels->'1'->>'type' as channel_1_type
-- FROM devices_with_channels
-- WHERE id = 'YOUR_DEVICE_ID';

-- 5. Count channels by type
SELECT 
  channel_type,
  COUNT(*) as count
FROM device_channels
GROUP BY channel_type;

-- 6. Find channels with NULL type (shouldn't exist if default is set)
SELECT 
  device_id,
  channel_no,
  label,
  channel_type
FROM device_channels
WHERE channel_type IS NULL;
