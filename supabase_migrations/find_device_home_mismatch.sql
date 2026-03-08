-- Find which home the devices are actually in vs which home is being queried

-- 1. Show the home being queried by the app
SELECT 
    'Home being queried' as info,
    '39dda668-cf92-4824-b4bb-7328fc56784d' as home_id,
    h.name as home_name,
    h.owner_id
FROM homes h
WHERE h.id = '39dda668-cf92-4824-b4bb-7328fc56784d';

-- 2. Show all devices and their actual home_id
SELECT 
    'Actual device homes' as info,
    d.id as device_id,
    d.display_name as device_name,
    d.home_id as actual_home_id,
    h.name as actual_home_name,
    d.owner_user_id
FROM devices d
LEFT JOIN homes h ON h.id = d.home_id
WHERE d.is_deleted = false
ORDER BY d.display_name;

-- 3. Count devices per home
SELECT 
    'Devices per home' as info,
    h.id as home_id,
    h.name as home_name,
    COUNT(d.id) as device_count
FROM homes h
LEFT JOIN devices d ON d.home_id = h.id AND d.is_deleted = false
GROUP BY h.id, h.name
ORDER BY device_count DESC;

-- 4. Show devices in the queried home (should be 0)
SELECT 
    'Devices in queried home' as info,
    d.id,
    d.display_name as name,
    d.device_type
FROM devices d
WHERE d.home_id = '39dda668-cf92-4824-b4bb-7328fc56784d'
AND d.is_deleted = false;

-- 5. Show all homes for the current user
SELECT 
    'User homes' as info,
    h.id as home_id,
    h.name as home_name,
    h.owner_id,
    CASE 
        WHEN h.owner_id = auth.uid() THEN 'Owner'
        ELSE 'Member'
    END as role
FROM homes h
LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid();
