-- ============================================================================
-- DATABASE VERIFICATION QUERIES FOR SCENE TRIGGERS
-- ============================================================================
-- Run these queries in Supabase SQL Editor to verify scene trigger implementation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CHECK ALL SCENES WITH TRIGGERS
-- ----------------------------------------------------------------------------
-- This query shows all scenes and their associated triggers
SELECT 
    s.id as scene_id,
    s.name as scene_name,
    s.is_enabled as scene_enabled,
    s.created_at as scene_created,
    st.id as trigger_id,
    st.kind as trigger_kind,
    st.config_json as trigger_config,
    st.is_enabled as trigger_enabled,
    st.created_at as trigger_created
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id
ORDER BY s.created_at DESC;

-- Expected Result:
-- - Scenes with "Time Based" trigger should have trigger_kind = 'schedule'
-- - trigger_config should contain: {"hour": X, "minute": Y, "days": [1,2,3,4,5,6,7]}
-- - trigger_enabled should be true


-- ----------------------------------------------------------------------------
-- 2. CHECK ONLY TIME-BASED TRIGGERS
-- ----------------------------------------------------------------------------
-- This query shows only scenes with schedule triggers
SELECT 
    s.name as scene_name,
    st.config_json->>'hour' as trigger_hour,
    st.config_json->>'minute' as trigger_minute,
    st.config_json->'days' as trigger_days,
    st.is_enabled as trigger_enabled,
    s.is_enabled as scene_enabled
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
ORDER BY 
    (st.config_json->>'hour')::int,
    (st.config_json->>'minute')::int;

-- Expected Result:
-- - All time-based triggers should appear here
-- - trigger_hour should be 0-23
-- - trigger_minute should be 0-59
-- - trigger_days should be [1,2,3,4,5,6,7] for daily triggers


-- ----------------------------------------------------------------------------
-- 3. CHECK SCENE STEPS (DEVICE ACTIONS)
-- ----------------------------------------------------------------------------
-- This query shows all scene steps with their action configurations
SELECT 
    s.name as scene_name,
    ss.step_order,
    ss.action_json->>'device_id' as device_id,
    ss.action_json->>'action_type' as action_type,
    ss.action_json as full_action_config,
    ss.created_at
FROM scene_steps ss
JOIN scenes s ON s.id = ss.scene_id
ORDER BY s.name, ss.step_order;

-- Expected Result:
-- - action_type should be 'power' for relay/dimmer or 'shutter' for shutters
-- - For power actions: should have 'channels' array and 'state' boolean
-- - For shutter actions: should have 'position' integer (0-100)


-- ----------------------------------------------------------------------------
-- 4. CHECK SCENE RUNS (EXECUTION HISTORY)
-- ----------------------------------------------------------------------------
-- This query shows recent scene executions
SELECT 
    s.name as scene_name,
    sr.started_at,
    sr.finished_at,
    sr.status,
    sr.logs_json,
    EXTRACT(EPOCH FROM (sr.finished_at - sr.started_at)) as duration_seconds
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
ORDER BY sr.started_at DESC
LIMIT 20;

-- Expected Result:
-- - status should be 'success' for successful executions
-- - logs_json should contain execution logs
-- - duration_seconds should be reasonable (< 10 seconds typically)


-- ----------------------------------------------------------------------------
-- 5. CHECK TRIGGERS THAT SHOULD FIRE SOON
-- ----------------------------------------------------------------------------
-- This query shows triggers that will fire in the next hour
-- Replace CURRENT_TIME with your local time if needed
SELECT 
    s.name as scene_name,
    st.config_json->>'hour' as trigger_hour,
    st.config_json->>'minute' as trigger_minute,
    EXTRACT(DOW FROM CURRENT_TIMESTAMP) + 1 as current_day_of_week,
    st.config_json->'days' as trigger_days,
    CASE 
        WHEN st.config_json->'days' @> to_jsonb(EXTRACT(DOW FROM CURRENT_TIMESTAMP)::int + 1)
        THEN 'Will fire today'
        ELSE 'Will NOT fire today (day not in schedule)'
    END as fires_today,
    st.is_enabled as trigger_enabled,
    s.is_enabled as scene_enabled
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
ORDER BY 
    (st.config_json->>'hour')::int,
    (st.config_json->>'minute')::int;

-- Expected Result:
-- - Shows which triggers will fire today based on day of week
-- - Both trigger_enabled and scene_enabled should be true for active triggers


-- ----------------------------------------------------------------------------
-- 6. FIND SCENES WITHOUT TRIGGERS
-- ----------------------------------------------------------------------------
-- This query shows scenes that don't have any triggers (manual only)
SELECT 
    s.id,
    s.name,
    s.is_enabled,
    s.created_at
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id
WHERE st.id IS NULL
ORDER BY s.created_at DESC;

-- Expected Result:
-- - These are scenes with "Manual" trigger type
-- - They can only be executed manually, not automatically


-- ----------------------------------------------------------------------------
-- 7. CHECK TRIGGER CONFIGURATION VALIDITY
-- ----------------------------------------------------------------------------
-- This query validates trigger configurations
SELECT 
    s.name as scene_name,
    st.id as trigger_id,
    st.config_json,
    CASE 
        WHEN st.config_json->>'hour' IS NULL THEN 'Missing hour'
        WHEN (st.config_json->>'hour')::int < 0 OR (st.config_json->>'hour')::int > 23 THEN 'Invalid hour (must be 0-23)'
        ELSE 'Hour OK'
    END as hour_validation,
    CASE 
        WHEN st.config_json->>'minute' IS NULL THEN 'Missing minute'
        WHEN (st.config_json->>'minute')::int < 0 OR (st.config_json->>'minute')::int > 59 THEN 'Invalid minute (must be 0-59)'
        ELSE 'Minute OK'
    END as minute_validation,
    CASE 
        WHEN st.config_json->'days' IS NULL THEN 'Missing days'
        WHEN jsonb_array_length(st.config_json->'days') = 0 THEN 'Empty days array'
        ELSE 'Days OK'
    END as days_validation
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule';

-- Expected Result:
-- - All validations should show "OK"
-- - If any show errors, the trigger configuration is invalid


-- ----------------------------------------------------------------------------
-- 8. COUNT SCENES BY TRIGGER TYPE
-- ----------------------------------------------------------------------------
-- This query shows statistics about trigger types
SELECT 
    COALESCE(st.kind, 'manual') as trigger_type,
    COUNT(*) as scene_count,
    COUNT(CASE WHEN s.is_enabled THEN 1 END) as enabled_count,
    COUNT(CASE WHEN NOT s.is_enabled THEN 1 END) as disabled_count
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id
GROUP BY COALESCE(st.kind, 'manual')
ORDER BY scene_count DESC;

-- Expected Result:
-- - Shows distribution of scenes by trigger type
-- - 'schedule' = time-based triggers
-- - 'manual' = no triggers (manual execution only)


-- ----------------------------------------------------------------------------
-- 9. CHECK RECENT AUTOMATIC EXECUTIONS
-- ----------------------------------------------------------------------------
-- This query shows scene runs that were likely triggered automatically
-- (runs that happened close to the trigger time)
SELECT 
    s.name as scene_name,
    st.config_json->>'hour' as trigger_hour,
    st.config_json->>'minute' as trigger_minute,
    EXTRACT(HOUR FROM sr.started_at) as actual_hour,
    EXTRACT(MINUTE FROM sr.started_at) as actual_minute,
    sr.started_at,
    sr.status,
    CASE 
        WHEN EXTRACT(HOUR FROM sr.started_at) = (st.config_json->>'hour')::int
         AND EXTRACT(MINUTE FROM sr.started_at) = (st.config_json->>'minute')::int
        THEN 'Triggered automatically'
        ELSE 'Possibly manual'
    END as execution_type
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
LEFT JOIN scene_triggers st ON st.scene_id = s.id AND st.kind = 'schedule'
ORDER BY sr.started_at DESC
LIMIT 20;

-- Expected Result:
-- - Shows which executions were automatic vs manual
-- - Automatic executions should match the trigger time exactly


-- ----------------------------------------------------------------------------
-- 10. FIND DUPLICATE TRIGGERS
-- ----------------------------------------------------------------------------
-- This query finds scenes with multiple triggers (should be rare)
SELECT 
    s.name as scene_name,
    COUNT(st.id) as trigger_count,
    array_agg(st.kind) as trigger_kinds,
    array_agg(st.id) as trigger_ids
FROM scenes s
JOIN scene_triggers st ON st.scene_id = s.id
GROUP BY s.id, s.name
HAVING COUNT(st.id) > 1
ORDER BY trigger_count DESC;

-- Expected Result:
-- - Should be empty (each scene should have at most 1 trigger)
-- - If any scenes have multiple triggers, this may indicate a bug


-- ============================================================================
-- QUICK VERIFICATION SCRIPT
-- ============================================================================
-- Run this to get a quick overview of the system state

DO $$
DECLARE
    total_scenes INT;
    scenes_with_triggers INT;
    schedule_triggers INT;
    enabled_triggers INT;
    recent_runs INT;
BEGIN
    SELECT COUNT(*) INTO total_scenes FROM scenes;
    SELECT COUNT(DISTINCT scene_id) INTO scenes_with_triggers FROM scene_triggers;
    SELECT COUNT(*) INTO schedule_triggers FROM scene_triggers WHERE kind = 'schedule';
    SELECT COUNT(*) INTO enabled_triggers FROM scene_triggers WHERE is_enabled = true;
    SELECT COUNT(*) INTO recent_runs FROM scene_runs WHERE started_at > NOW() - INTERVAL '24 hours';
    
    RAISE NOTICE '=== SCENE TRIGGER SYSTEM STATUS ===';
    RAISE NOTICE 'Total Scenes: %', total_scenes;
    RAISE NOTICE 'Scenes with Triggers: %', scenes_with_triggers;
    RAISE NOTICE 'Time-Based Triggers: %', schedule_triggers;
    RAISE NOTICE 'Enabled Triggers: %', enabled_triggers;
    RAISE NOTICE 'Scene Runs (Last 24h): %', recent_runs;
    RAISE NOTICE '===================================';
END $$;

-- Expected Output:
-- NOTICE:  === SCENE TRIGGER SYSTEM STATUS ===
-- NOTICE:  Total Scenes: X
-- NOTICE:  Scenes with Triggers: Y
-- NOTICE:  Time-Based Triggers: Z
-- NOTICE:  Enabled Triggers: Z
-- NOTICE:  Scene Runs (Last 24h): N
-- NOTICE:  ===================================

