-- Diagnostic queries to identify why devices aren't showing in scenes

-- 1. Check if devices table has data
SELECT 
    'Total devices in database' as check_name,
    COUNT(*) as count
FROM devices;

-- 2. Check devices by home
SELECT 
    'Devices per home' as check_name,
    h.name as home_name,
    h.id as home_id,
    COUNT(d.id) as device_count
FROM homes h
LEFT JOIN devices d ON d.home_id = h.id AND d.is_deleted = false
GROUP BY h.id, h.name
ORDER BY device_count DESC;

-- 3. Check if devices_with_channels view exists and has data
SELECT 
    'Devices in view' as check_name,
    COUNT(*) as count
FROM devices_with_channels;

-- 4. Check for devices without home_id
SELECT 
    'Devices without home_id' as check_name,
    COUNT(*) as count
FROM devices
WHERE home_id IS NULL AND is_deleted = false;

-- 5. Check for deleted devices
SELECT 
    'Deleted devices' as check_name,
    COUNT(*) as count
FROM devices
WHERE is_deleted = true;

-- 6. Sample device data (first 5 devices)
SELECT 
    d.id,
    d.name,
    d.display_name,
    d.home_id,
    d.room_id,
    d.device_type,
    d.online,
    d.is_deleted,
    h.name as home_name
FROM devices d
LEFT JOIN homes h ON h.id = d.home_id
WHERE d.is_deleted = false
LIMIT 5;

-- 7. Check if the view has all necessary columns
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'devices_with_channels'
ORDER BY ordinal_position;
