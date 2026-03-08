-- Verification Script for Timezone Fix
-- Run this after deploying the fix to verify everything works

-- ========================================
-- 1. Verify RPC Function Exists
-- ========================================
SELECT 'Step 1: Checking if get_server_time() function exists...' as step;

SELECT 
  proname as function_name,
  pg_get_functiondef(oid) as definition
FROM pg_proc
WHERE proname = 'get_server_time';

-- Expected: Should return one row with function definition

-- ========================================
-- 2. Test RPC Function
-- ========================================
SELECT 'Step 2: Testing get_server_time() function...' as step;

SELECT public.get_server_time();

-- Expected: {"utc_now": "2024-01-15 10:30:45.123456", "timezone": "UTC"}

-- ========================================
-- 3. Check Current Server Time
-- ========================================
SELECT 'Step 3: Checking server times...' as step;

SELECT 
  now() as server_local_time,
  now() AT TIME ZONE 'UTC' as server_utc_time,
  now() AT TIME ZONE 'Africa/Cairo' as egypt_time;

-- This shows the current time in different timezones

-- ========================================
-- 4. Check Existing Scene Triggers
-- ========================================
SELECT 'Step 4: Checking existing scene triggers...' as step;

SELECT 
  st.id,
  s.name as scene_name,
  st.kind,
  st.config_json->>'hour' as stored_hour,
  st.config_json->>'minute' as stored_minute,
  st.config_json->'days' as days,
  st.is_enabled,
  st.created_at
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
ORDER BY st.created_at DESC;

-- Check if hour values look like UTC (should be 2 hours less than Egypt time)

-- ========================================
-- 5. Verify Timezone Conversion
-- ========================================
SELECT 'Step 5: Verifying timezone conversion...' as step;

-- Example: If user selected 12:00 PM Egypt, it should be stored as 10:00 UTC
SELECT 
  st.id,
  s.name,
  st.config_json->>'hour' as utc_hour,
  st.config_json->>'minute' as utc_minute,
  -- Convert back to Egypt time for verification
  ((st.config_json->>'hour')::int + 2) % 24 as egypt_hour,
  st.config_json->>'minute' as egypt_minute
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
ORDER BY st.created_at DESC
LIMIT 5;

-- Verify: egypt_hour should be 2 hours ahead of utc_hour

-- ========================================
-- 6. Check Next Trigger Times
-- ========================================
SELECT 'Step 6: Calculating next trigger times...' as step;

WITH current_time AS (
  SELECT 
    EXTRACT(HOUR FROM now() AT TIME ZONE 'UTC') as current_utc_hour,
    EXTRACT(MINUTE FROM now() AT TIME ZONE 'UTC') as current_utc_minute,
    EXTRACT(DOW FROM now() AT TIME ZONE 'Africa/Cairo') as current_egypt_dow
)
SELECT 
  s.name as scene_name,
  st.config_json->>'hour' as trigger_utc_hour,
  st.config_json->>'minute' as trigger_utc_minute,
  ((st.config_json->>'hour')::int + 2) % 24 as trigger_egypt_hour,
  st.config_json->>'minute' as trigger_egypt_minute,
  st.config_json->'days' as trigger_days,
  ct.current_utc_hour,
  ct.current_utc_minute,
  CASE 
    WHEN (st.config_json->>'hour')::int = ct.current_utc_hour::int 
     AND (st.config_json->>'minute')::int = ct.current_utc_minute::int
    THEN '🔥 TRIGGERING NOW!'
    WHEN (st.config_json->>'hour')::int > ct.current_utc_hour::int
      OR ((st.config_json->>'hour')::int = ct.current_utc_hour::int 
          AND (st.config_json->>'minute')::int > ct.current_utc_minute::int)
    THEN '⏰ Will trigger later today'
    ELSE '📅 Will trigger tomorrow'
  END as status
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
CROSS JOIN current_time ct
WHERE st.kind = 'schedule'
  AND st.is_enabled = true
  AND s.is_enabled = true
ORDER BY st.config_json->>'hour', st.config_json->>'minute';

-- ========================================
-- 7. Test Conversion Examples
-- ========================================
SELECT 'Step 7: Testing conversion examples...' as step;

-- Example conversions
SELECT 
  'Conversion Examples' as description,
  jsonb_build_object(
    'example_1', jsonb_build_object(
      'egypt_time', '12:00 PM',
      'utc_hour', 10,
      'utc_minute', 0,
      'note', '12:00 PM Egypt = 10:00 AM UTC'
    ),
    'example_2', jsonb_build_object(
      'egypt_time', '11:00 PM',
      'utc_hour', 21,
      'utc_minute', 0,
      'note', '11:00 PM Egypt = 9:00 PM UTC'
    ),
    'example_3', jsonb_build_object(
      'egypt_time', '1:00 AM',
      'utc_hour', 23,
      'utc_minute', 0,
      'note', '1:00 AM Egypt = 11:00 PM UTC (previous day)'
    )
  ) as examples;

-- ========================================
-- 8. Check for Potential Issues
-- ========================================
SELECT 'Step 8: Checking for potential issues...' as step;

-- Check for triggers with suspicious hour values
SELECT 
  s.name,
  st.config_json->>'hour' as hour,
  st.config_json->>'minute' as minute,
  CASE 
    WHEN (st.config_json->>'hour')::int BETWEEN 0 AND 23 THEN '✅ Valid'
    ELSE '❌ Invalid hour'
  END as hour_validation,
  CASE 
    WHEN (st.config_json->>'minute')::int BETWEEN 0 AND 59 THEN '✅ Valid'
    ELSE '❌ Invalid minute'
  END as minute_validation
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule';

-- ========================================
-- Summary
-- ========================================
SELECT 'Verification complete!' as summary;

SELECT 
  'Summary' as section,
  COUNT(*) as total_schedule_triggers,
  COUNT(*) FILTER (WHERE is_enabled = true) as enabled_triggers,
  COUNT(*) FILTER (WHERE is_enabled = false) as disabled_triggers
FROM scene_triggers
WHERE kind = 'schedule';

-- ========================================
-- Next Steps
-- ========================================
SELECT 'Next Steps:' as instructions;
SELECT '1. Verify RPC function exists and works' as step_1;
SELECT '2. Check existing triggers have UTC hour values (2 hours less than Egypt)' as step_2;
SELECT '3. Create a test scene with current time + 2 minutes' as step_3;
SELECT '4. Verify it triggers at the correct Egypt time' as step_4;
SELECT '5. Check edge function logs at trigger time' as step_5;
