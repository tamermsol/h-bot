# Scene Automation Backend Setup Guide

This guide explains how to set up the backend infrastructure for automated scene triggers that work even when the app is fully closed.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Supabase Backend                          │
│                                                              │
│  ┌──────────────────┐         ┌─────────────────────┐      │
│  │  Cron Job        │────────>│  Edge Function      │      │
│  │  (Every minute)  │         │  scene-trigger-     │      │
│  └──────────────────┘         │  monitor            │      │
│                                └──────────┬──────────┘      │
│                                           │                  │
│                                           v                  │
│                                ┌──────────────────────┐     │
│                                │  scene_commands      │     │
│                                │  Table               │     │
│                                └──────────┬───────────┘     │
│                                           │                  │
└───────────────────────────────────────────┼─────────────────┘
                                            │
                                            │ Realtime
                                            │ Subscription
                                            v
                                ┌──────────────────────┐
                                │  Flutter App         │
                                │  SceneCommandExecutor│
                                │  ↓                   │
                                │  MQTT Device Manager │
                                └──────────────────────┘
```

## Step 1: Deploy the Database Migration

Run the SQL migration to create the `scene_commands` table:

```bash
# Using Supabase CLI
supabase db push

# Or manually run the SQL in Supabase Dashboard > SQL Editor
```

The migration file is located at: `supabase_migrations/create_scene_commands_table.sql`

## Step 2: Deploy the Edge Function

### Option A: Using Supabase CLI (Recommended)

```bash
# Install Supabase CLI if not already installed
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the edge function
supabase functions deploy scene-trigger-monitor
```

### Option B: Manual Deployment via Dashboard

1. Go to Supabase Dashboard > Edge Functions
2. Click "Create a new function"
3. Name it: `scene-trigger-monitor`
4. Copy the code from `supabase/functions/scene-trigger-monitor/index.ts`
5. Click "Deploy"

## Step 3: Set Up Cron Job

The edge function needs to run every minute to check for triggers.

### Option A: Using pg_cron (Recommended for Production)

1. Enable pg_cron extension in Supabase Dashboard:
   - Go to Database > Extensions
   - Search for "pg_cron"
   - Enable it

2. Create the cron job in SQL Editor:

```sql
-- Schedule the edge function to run every minute
SELECT cron.schedule(
  'scene-trigger-monitor',
  '* * * * *',  -- Every minute
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
```

Replace:
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_SERVICE_ROLE_KEY` with your service role key (from Settings > API)

### Option B: Using External Cron Service (Alternative)

If pg_cron is not available, use an external service like:

1. **Cron-job.org** (Free)
   - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor`
   - Method: POST
   - Headers: `Authorization: Bearer YOUR_SERVICE_ROLE_KEY`
   - Schedule: Every 1 minute

2. **GitHub Actions** (Free for public repos)
   - Create `.github/workflows/scene-trigger.yml`:

```yaml
name: Scene Trigger Monitor
on:
  schedule:
    - cron: '* * * * *'  # Every minute
  workflow_dispatch:

jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - name: Call Edge Function
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

3. **EasyCron** (Free tier available)
4. **AWS EventBridge** (Pay as you go)

## Step 4: Verify Setup

### Test the Edge Function Manually

```bash
# Using curl
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor

# Expected response:
{
  "success": true,
  "timestamp": "2024-01-01T12:00:00.000Z",
  "triggered_scenes": [],
  "message": "Processed 0 scene(s), triggered 0"
}
```

### Check Logs

1. Go to Supabase Dashboard > Edge Functions > scene-trigger-monitor
2. Click "Logs" tab
3. You should see logs like:
   ```
   🔍 Checking triggers at 12:00
   No enabled scenes with triggers found
   ```

### Test with a Real Scene

1. Create a scene in your app
2. Add a schedule trigger for the current time + 1 minute
3. Wait for the trigger time
4. Check:
   - Edge function logs (should show "Trigger matched")
   - `scene_commands` table (should have a new row)
   - `scene_runs` table (should have a new run)
   - Your app should execute the command via MQTT

## Step 5: Monitor and Maintain

### View Cron Job Status

```sql
-- List all cron jobs
SELECT * FROM cron.job;

-- View cron job run history
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 10;
```

### Cleanup Old Commands

The migration includes a cleanup function. To run it manually:

```sql
SELECT cleanup_old_scene_commands();
```

Or schedule it to run daily:

```sql
SELECT cron.schedule(
  'cleanup-scene-commands',
  '0 2 * * *',  -- Daily at 2 AM
  'SELECT cleanup_old_scene_commands()'
);
```

## Troubleshooting

### Edge Function Not Triggering

1. Check cron job is running:
   ```sql
   SELECT * FROM cron.job_run_details
   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'scene-trigger-monitor')
   ORDER BY start_time DESC
   LIMIT 5;
   ```

2. Check edge function logs in Supabase Dashboard

3. Verify service role key is correct

### Commands Not Executing in App

1. Check if app is connected to Supabase Realtime
2. Verify `SceneCommandExecutor` is started in `main.dart`
3. Check app logs for "🎬 SceneCommandExecutor" messages
4. Verify MQTT connection is active

### Scenes Not Triggering at Correct Time

1. Verify trigger configuration in database:
   ```sql
   SELECT * FROM scene_triggers WHERE is_enabled = true;
   ```

2. Check timezone settings (edge function uses UTC)
3. Verify scene is enabled:
   ```sql
   SELECT * FROM scenes WHERE is_enabled = true;
   ```

## Cost Estimation

### Supabase Free Tier
- Edge Function invocations: 500,000/month (60 * 24 * 30 = 43,200/month used)
- Database operations: Included
- Realtime connections: 200 concurrent (1 per active user)

**Result: Completely free for most use cases!**

### Paid Tier (if needed)
- Pro Plan: $25/month
- Includes 2M edge function invocations
- Unlimited database operations

## Security Notes

1. **Never expose service role key** in client code
2. Edge function uses service role to bypass RLS (required)
3. Mobile app uses user auth tokens (RLS enforced)
4. Commands are scoped to user's devices via RLS policies

## Next Steps

1. ✅ Deploy database migration
2. ✅ Deploy edge function
3. ✅ Set up cron job
4. ✅ Test with a sample scene
5. 🎉 Enjoy automated scenes even when app is closed!

## Support

If you encounter issues:
1. Check Supabase Dashboard > Edge Functions > Logs
2. Check app logs for SceneCommandExecutor messages
3. Verify database tables have correct data
4. Test edge function manually with curl
