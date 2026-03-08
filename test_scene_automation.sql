-- Test Script for Scene Automation Backend
-- Run these queries to verify your setup is working correctly

-- ========================================
-- 1. Verify Tables Exist
-- ========================================
SELECT 'Checking if scene_commands table exists...' as step;
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'scene_commands'
) as scene_commands_exists;

-- ========================================
-- 2. Verify Extensions
-- ========================================
SELECT 'Checking required extensions...' as step;
SELECT 
  extname,
  extversion
FROM pg_extension
WHERE extname IN ('pg_cron', 'http');

-- ========================================
-- 3. Check Cron Jobs
-- ========================================
SELECT 'Checking cron jobs...' as step;
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  database
FROM cron.job
WHERE jobname IN ('scene-trigger-monitor', 'cleanup-scene-commands');

-- ========================================
-- 4. View Recent Cron Runs
-- ========================================
SELECT 'Checking recent cron job runs...' as step;
SELECT 
  job_run_details.jobid,
  job.jobname,
  job_run_details.start_time,
  job_run_details.end_time,
  job_run_details.status,
  LEFT(job_run_details.return_message, 100) as return_message_preview
FROM cron.job_run_details
JOIN cron.job ON job.jobid = job_run_details.jobid
WHERE job.jobname = 'scene-trigger-monitor'
ORDER BY start_time DESC
LIMIT 5;

-- ========================================
-- 5. Check Enabled Scenes
-- ========================================
SELECT 'Checking enabled scenes...' as step;
SELECT 
  s.id,
  s.name,
  s.is_enabled,
  COUNT(st.id) as trigger_count
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id AND st.is_enabled = true
WHERE s.is_enabled = true
GROUP BY s.id, s.name, s.is_enabled;

-- ========================================
-- 6. Check Scene Triggers
-- ========================================
SELECT 'Checking scene triggers...' as step;
SELECT 
  st.id,
  s.name as scene_name,
  st.kind,
  st.config_json,
  st.is_enabled
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.is_enabled = true
ORDER BY s.name, st.kind;

-- ========================================
-- 7. Check Pending Commands
-- ========================================
SELECT 'Checking pending scene commands...' as step;
SELECT 
  sc.id,
  s.name as scene_name,
  sc.action_type,
  sc.created_at,
  sc.executed,
  sc.error_message
FROM scene_commands sc
LEFT JOIN scene_runs sr ON sr.id = sc.scene_run_id
LEFT JOIN scenes s ON s.id = sr.scene_id
WHERE sc.executed = false
ORDER BY sc.created_at DESC;

-- ========================================
-- 8. Check Recent Scene Runs
-- ========================================
SELECT 'Checking recent scene runs...' as step;
SELECT 
  sr.id,
  s.name as scene_name,
  sr.started_at,
  sr.finished_at,
  sr.status,
  sr.logs_json->'logs' as logs
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
ORDER BY sr.started_at DESC
LIMIT 10;

-- ========================================
-- 9. Check RLS Policies
-- ========================================
SELECT 'Checking RLS policies on scene_commands...' as step;
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies
WHERE tablename = 'scene_commands';

-- ========================================
-- 10. Test Scene Command Insertion (Manual Test)
-- ========================================
-- Uncomment to test inserting a command manually
-- This simulates what the edge function does

/*
SELECT 'Testing manual command insertion...' as step;

-- First, get a test device and scene
WITH test_data AS (
  SELECT 
    d.id as device_id,
    d.topic_base,
    s.id as scene_id
  FROM devices d
  CROSS JOIN scenes s
  WHERE d.device_type = 'relay'
  LIMIT 1
)
INSERT INTO scene_commands (
  device_id,
  topic_base,
  action_type,
  action_data,
  executed
)
SELECT 
  device_id,
  topic_base,
  'power',
  jsonb_build_object(
    'device_id', device_id,
    'action_type', 'power',
    'channels', ARRAY[1],
    'state', true
  ),
  false
FROM test_data
RETURNING *;
*/

-- ========================================
-- Summary
-- ========================================
SELECT 'Setup verification complete!' as step;
SELECT 
  'If all checks passed, your scene automation backend is ready!' as message;
