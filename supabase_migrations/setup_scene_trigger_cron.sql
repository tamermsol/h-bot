-- Setup Cron Job for Scene Trigger Monitor
-- This will call the edge function every minute to check for scene triggers

-- First, enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable http extension for making HTTP requests
CREATE EXTENSION IF NOT EXISTS http;

-- Unschedule existing job if it exists (for re-running this script)
SELECT cron.unschedule('scene-trigger-monitor') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'scene-trigger-monitor'
);

-- Schedule the edge function to run every minute
-- IMPORTANT: Replace YOUR_PROJECT_REF and YOUR_SERVICE_ROLE_KEY with your actual values
SELECT cron.schedule(
  'scene-trigger-monitor',           -- Job name
  '* * * * *',                        -- Every minute (cron expression)
  $$
  SELECT
    net.http_post(
      url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
      ),
      body := '{}'::jsonb
    ) as request_id;
  $$
);

-- Verify the cron job was created
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  database
FROM cron.job
WHERE jobname = 'scene-trigger-monitor';

-- View recent cron job runs (after waiting a few minutes)
-- SELECT 
--   job_run_details.jobid,
--   job.jobname,
--   job_run_details.start_time,
--   job_run_details.end_time,
--   job_run_details.status,
--   job_run_details.return_message
-- FROM cron.job_run_details
-- JOIN cron.job ON job.jobid = job_run_details.jobid
-- WHERE job.jobname = 'scene-trigger-monitor'
-- ORDER BY start_time DESC
-- LIMIT 10;

-- Optional: Schedule cleanup job to run daily at 2 AM
SELECT cron.schedule(
  'cleanup-scene-commands',
  '0 2 * * *',  -- Daily at 2 AM
  'SELECT cleanup_old_scene_commands()'
);

-- Verify cleanup job was created
SELECT 
  jobid,
  jobname,
  schedule,
  active
FROM cron.job
WHERE jobname = 'cleanup-scene-commands';
