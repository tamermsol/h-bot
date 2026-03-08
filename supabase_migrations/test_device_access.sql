-- Test device access for the current authenticated user
-- Run this query while logged in as the user having issues

-- 1. Check current user
SELECT 
    'Current User' as info,
    auth.uid() as user_id,
    auth.email() as email;

-- 2. Check user's homes
SELECT 
    'User Homes' as info,
    h.id as home_id,
    h.name as home_name,
    h.owner_id,
    CASE 
        WHEN h.owner_id = auth.uid() THEN 'Owner'
        ELSE 'Member'
    END as relationship
FROM homes h
LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid();

-- 3. Check devices in user's homes (through view)
SELECT 
    'Devices via View' as info,
    d.id,
    d.name,
    d.home_id,
    d.device_type,
    d.online
FROM devices_with_channels d
WHERE d.home_id IN (
    SELECT h.id
    FROM homes h
    LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
    WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid()
);

-- 4. Check devices directly from table (bypassing view)
SELECT 
    'Devices Direct' as info,
    d.id,
    d.display_name as name,
    d.home_id,
    d.device_type,
    d.online,
    d.is_deleted
FROM devices d
WHERE d.home_id IN (
    SELECT h.id
    FROM homes h
    LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
    WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid()
)
AND d.is_deleted = false;

-- 5. Count devices per home for current user
SELECT 
    h.id as home_id,
    h.name as home_name,
    COUNT(d.id) as device_count
FROM homes h
LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
LEFT JOIN devices d ON d.home_id = h.id AND d.is_deleted = false
WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid()
GROUP BY h.id, h.name
ORDER BY device_count DESC;

-- 6. Check if RLS is blocking access
-- This will show if there are devices in the table that the user can't see
SELECT 
    'RLS Check' as info,
    (SELECT COUNT(*) FROM devices WHERE is_deleted = false) as total_devices_in_db,
    (SELECT COUNT(*) FROM devices_with_channels) as devices_user_can_see,
    CASE 
        WHEN (SELECT COUNT(*) FROM devices WHERE is_deleted = false) > (SELECT COUNT(*) FROM devices_with_channels)
        THEN 'RLS is blocking some devices'
        ELSE 'RLS is working correctly'
    END as rls_status;
