-- Verify which home the app should be using

-- 1. Check if the queried home exists and belongs to current user
SELECT 
    'Queried home check' as info,
    h.id,
    h.name,
    h.owner_id,
    CASE 
        WHEN h.owner_id = auth.uid() THEN 'You own this home'
        WHEN EXISTS (SELECT 1 FROM home_members WHERE home_id = h.id AND user_id = auth.uid()) THEN 'You are a member'
        ELSE 'NO ACCESS'
    END as access_status
FROM homes h
WHERE h.id = '39dda668-cf92-4824-b4bb-7328fc56784d';

-- 2. Show homes with devices that the user can access
SELECT 
    'Homes with devices' as info,
    h.id as home_id,
    h.name as home_name,
    COUNT(d.id) as device_count,
    CASE 
        WHEN h.owner_id = auth.uid() THEN 'Owner'
        ELSE 'Member'
    END as your_role
FROM homes h
LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
LEFT JOIN devices d ON d.home_id = h.id AND d.is_deleted = false
WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid()
GROUP BY h.id, h.name, h.owner_id
HAVING COUNT(d.id) > 0
ORDER BY device_count DESC;

-- 3. Show the first home with devices (this should be the default)
SELECT 
    'Recommended home' as info,
    h.id as home_id,
    h.name as home_name,
    COUNT(d.id) as device_count
FROM homes h
LEFT JOIN home_members hm ON hm.home_id = h.id AND hm.user_id = auth.uid()
LEFT JOIN devices d ON d.home_id = h.id AND d.is_deleted = false
WHERE h.owner_id = auth.uid() OR hm.user_id = auth.uid()
GROUP BY h.id, h.name
HAVING COUNT(d.id) > 0
ORDER BY device_count DESC
LIMIT 1;
