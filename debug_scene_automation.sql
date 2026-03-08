-- Debug Script for Scene Automation
-- Run these queries one by one to find the issue

-- ========================================
-- 1. Check if pg_cron extension is enabled
-- ========================================
SELECT 'Step 1: Checking pg_cron extension...' as step;
SELECT 
  extname,
  extversion
FROM pg_extension
WHERE extname = 'pg_cron';
-- Expected: Should return one row with pg_cron
-- If empty: Run "CREATE EXTENSION pg_cron;"

-- ========================================
-- 2. Check if cron job exists
-- ========================================
SELECT 'Step 2: Checking if cron job exists...' as step;
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  database
FROM cron.job
WHERE jobname = 'scene-trigger-monitor';
-- Expected: Should return one row
-- If empty: Cron job not created yet

-- ========================================
-- 3. Check recent cron job runs
-- ========================================
SELECT 'Step 3: Checking recent cron job runs...' as step;
SELECT 
  job_run_details.jobid,
  job.jobname,
  job_run_details.start_time,
  job_run_details.end_time,
  job_run_details.status,
  job_run_details.return_message
FROM cron.job_run_details
JOIN cron.job ON job.jobid = job_run_details.jobid
WHERE job.jobname = 'scene-trigger-monitor'
ORDER BY start_time DESC
LIMIT 5;
-- Expected: Should show runs every minute
-- If empty: Cron job hasn't run yet

-- ========================================
-- 4. Check if scenes exist
-- ========================================
SELECT 'Step 4: Checking enabled scenes...' as step;
SELECT 
  id,
  name,
  is_enabled,
  created_at
FROM scenes
WHERE is_enabled = true;
-- Expected: Should show your scenes
-- If empty: No enabled scenes

-- ========================================
-- 5. Check if scene triggers exist
-- ========================================
SELECT 'Step 5: Checking scene triggers...' as step;
SELECT 
  st.id,
  s.name as scene_name,
  st.kind,
  st.config_json,
  st.is_enabled
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.is_enabled = true
  AND s.is_enabled = true;
-- Expected: Should show your time triggers
-- If empty: No triggers configured

-- ========================================
-- 6. Check scene steps (device actions)
-- ========================================
SELECT 'Step 6: Checking scene steps...' as step;
SELECT 
  ss.id,
  s.name as scene_name,
  ss.step_order,
  ss.action_json
FROM scene_steps ss
JOIN scenes s ON s.id = ss.scene_id
WHERE s.is_enabled = true
ORDER BY s.name, ss.step_order;
-- Expected: Should show device actions
-- If empty: No device actions configured

-- ========================================
-- 7. Check scene_commands table
-- ========================================
SELECT 'Step 7: Checking scene_commands table...' as step;
SELECT 
  sc.id,
  s.name as scene_name,
  sc.device_id,
  sc.action_type,
  sc.action_data,
  sc.created_at,
  sc.executed
FROM scene_commands sc
LEFT JOIN scene_runs sr ON sr.id = sc.scene_run_id
LEFT JOIN scenes s ON s.id = sr.scene_id
ORDER BY sc.created_at DESC
LIMIT 10;
-- Expected: Should show commands if edge function ran
-- If empty: Edge function hasn't created commands yet

-- ========================================
-- 8. Check scene_runs table
-- ========================================
SELECT 'Step 8: Checking scene_runs...' as step;
SELECT 
  sr.id,
  s.name as scene_name,
  sr.started_at,
  sr.finished_at,
  sr.status,
  sr.logs_json
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
ORDER BY sr.started_at DESC
LIMIT 10;
-- Expected: Should show scene executions
-- If empty: No scenes have been executed

-- ========================================
-- 9. Test edge function URL (manual test)
-- ========================================
SELECT 'Step 9: Manual edge function test...' as step;
SELECT 'Run this in your terminal:' as instruction;
SELECT 'curl -X POST -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor' as command;

-- ========================================
-- 10. Check current time vs trigger time
-- ========================================
SELECT 'Step 10: Checking current time vs trigger times...' as step;
SELECT 
  s.name as scene_name,
  st.config_json->>'hour' as trigger_hour,
  st.config_json->>'minute' as trigger_minute,
  st.config_json->'days' as trigger_days,
  EXTRACT(HOUR FROM NOW()) as current_hour,
  EXTRACT(MINUTE FROM NOW()) as current_minute,
  EXTRACT(DOW FROM NOW()) as current_day_of_week,
  CASE 
    WHEN EXTRACT(DOW FROM NOW()) = 0 THEN 7  -- Sunday
    ELSE EXTRACT(DOW FROM NOW())
  END as current_day_adjusted
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
  AND st.is_enabled = true
  AND s.is_enabled = true;
-- This shows if your trigger time matches current time

-- ========================================
-- SUMMARY
-- ========================================
SELECT 'Debug complete! Check results above.' as summary;
