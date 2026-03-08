-- Detailed diagnostic to check actual device data

-- 1. Check total devices in the view
SELECT 
    'Total devices in view' as check_name,
    COUNT(*) as count
FROM devices_with_channels;

-- 2. Check devices grouped by home
SELECT 
    'Devices per home' as check_name,
    home_id,
    COUNT(*) as device_count
FROM devices_with_channels
GROUP BY home_id
ORDER BY device_count DESC;

-- 3. Check all homes with their device counts
SELECT 
    h.id as home_id,
    h.name as home_name,
    h.owner_id,
    COUNT(d.id) as device_count
FROM homes h
LEFT JOIN devices_with_channels d ON d.home_id = h.id
GROUP BY h.id, h.name, h.owner_id
ORDER BY device_count DESC;

-- 4. Show sample devices with all details
SELECT 
    id,
    name,
    display_name,
    home_id,
    room_id,
    device_type,
    channels,
    channel_count,
    online,
    is_deleted
FROM devices_with_channels
LIMIT 10;

-- 5. Check for devices without home_id
SELECT 
    'Devices without home_id' as issue,
    COUNT(*) as count
FROM devices
WHERE home_id IS NULL AND is_deleted = false;

-- 6. Check the current user's homes (replace with your user_id)
-- You need to run this with your actual user_id
-- SELECT 
--     h.id,
--     h.name,
--     hm.role
-- FROM homes h
-- JOIN home_members hm ON hm.home_id = h.id
-- WHERE hm.user_id = 'YOUR_USER_ID_HERE';

-- 7. Check RLS policies on devices_with_channels
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'devices'
ORDER BY policyname;
