# Scene Automation Deployment Checklist

Use this checklist to deploy the scene automation backend to production.

## Pre-Deployment

- [ ] Read `SCENE_AUTOMATION_QUICK_START.md`
- [ ] Have Supabase project credentials ready
- [ ] Backup your database (optional but recommended)

## Step 1: Database Setup

- [ ] Open Supabase Dashboard > SQL Editor
- [ ] Run `supabase_migrations/create_scene_commands_table.sql`
- [ ] Verify table created: `SELECT * FROM scene_commands LIMIT 1;`
- [ ] Check RLS policies: `SELECT * FROM pg_policies WHERE tablename = 'scene_commands';`

**Expected Result:** Table exists with 3 RLS policies

## Step 2: Edge Function Deployment

### Option A: Supabase CLI (Recommended)

- [ ] Install Supabase CLI: `npm install -g supabase`
- [ ] Login: `supabase login`
- [ ] Link project: `supabase link --project-ref YOUR_PROJECT_REF`
- [ ] Deploy: `supabase functions deploy scene-trigger-monitor`
- [ ] Verify in Dashboard > Edge Functions

### Option B: Manual Deployment

- [ ] Go to Supabase Dashboard > Edge Functions
- [ ] Click "Create a new function"
- [ ] Name: `scene-trigger-monitor`
- [ ] Copy code from `supabase/functions/scene-trigger-monitor/index.ts`
- [ ] Click "Deploy"

**Expected Result:** Function appears in Edge Functions list

## Step 3: Get Credentials

- [ ] Run `get_supabase_config.bat`
- [ ] Copy your Project Ref
- [ ] Copy your Service Role Key (keep it secret!)

**Expected Result:** You have both credentials ready

## Step 4: Setup Cron Job

- [ ] Open `supabase_migrations/setup_scene_trigger_cron.sql`
- [ ] Replace `YOUR_PROJECT_REF` with your actual project ref
- [ ] Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key
- [ ] Run the SQL in Supabase Dashboard > SQL Editor
- [ ] Verify cron job created: `SELECT * FROM cron.job WHERE jobname = 'scene-trigger-monitor';`

**Expected Result:** Cron job appears with schedule `* * * * *`

## Step 5: Test Edge Function

- [ ] Test manually with curl:
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

- [ ] Check response is JSON with `success: true`
- [ ] Check logs in Dashboard > Edge Functions > scene-trigger-monitor > Logs

**Expected Result:** 
```json
{
  "success": true,
  "timestamp": "2024-01-01T12:00:00.000Z",
  "triggered_scenes": [],
  "message": "Processed X scene(s), triggered 0"
}
```

## Step 6: Verify Cron is Running

- [ ] Wait 2-3 minutes
- [ ] Run verification query:
```sql
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'scene-trigger-monitor')
ORDER BY start_time DESC
LIMIT 5;
```

- [ ] Check status is 'succeeded'
- [ ] Check edge function logs show recent executions

**Expected Result:** Multiple successful runs every minute

## Step 7: Update Flutter App

- [ ] Verify `lib/services/scene_command_executor.dart` exists
- [ ] Verify `lib/main.dart` has been updated
- [ ] Run `flutter pub get`
- [ ] Build app: `flutter build apk --release` (Android)
- [ ] Or: `flutter build ios --release` (iOS)

**Expected Result:** App builds successfully

## Step 8: Test End-to-End

### Create Test Scene

- [ ] Open your app
- [ ] Create a new scene
- [ ] Add a device action (turn on a light)
- [ ] Add a schedule trigger for current time + 2 minutes
- [ ] Enable the scene

### Test with App Open

- [ ] Keep app open
- [ ] Wait for trigger time
- [ ] Scene should execute automatically
- [ ] Check logs: `SELECT * FROM scene_runs ORDER BY started_at DESC LIMIT 1;`

**Expected Result:** Scene executes, device responds

### Test with App Closed

- [ ] Create another scene with trigger for current time + 2 minutes
- [ ] **Close app completely** (swipe away from recent apps)
- [ ] Wait for trigger time
- [ ] Check database: `SELECT * FROM scene_commands WHERE executed = false;`
- [ ] Should see pending command
- [ ] Open app
- [ ] Command should execute immediately
- [ ] Check: `SELECT * FROM scene_commands WHERE id = 'COMMAND_ID';`
- [ ] `executed` should be `true`

**Expected Result:** Scene executes when app opens

## Step 9: Monitoring Setup

- [ ] Bookmark edge function logs page
- [ ] Save these queries for monitoring:

```sql
-- Check pending commands
SELECT * FROM scene_commands WHERE executed = false;

-- Check recent runs
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC LIMIT 10;

-- Check scene execution history
SELECT * FROM scene_runs ORDER BY started_at DESC LIMIT 10;
```

## Step 10: Production Deployment

- [ ] Deploy app to Google Play / App Store
- [ ] Update app version in stores
- [ ] Monitor edge function logs for first 24 hours
- [ ] Check for any errors in `scene_commands` table
- [ ] Verify cron job runs consistently

## Post-Deployment Verification

### Day 1
- [ ] Check edge function ran 1,440 times (60 × 24)
- [ ] Verify no errors in logs
- [ ] Check user feedback

### Week 1
- [ ] Monitor database size
- [ ] Check cleanup job ran (daily at 2 AM)
- [ ] Verify old commands are deleted
- [ ] Review any error messages

### Month 1
- [ ] Check Supabase usage stats
- [ ] Verify still within free tier
- [ ] Review scene execution success rate
- [ ] Gather user feedback

## Rollback Plan (If Needed)

If something goes wrong:

1. **Disable Cron Job**
```sql
SELECT cron.unschedule('scene-trigger-monitor');
```

2. **Stop Edge Function**
   - Dashboard > Edge Functions > scene-trigger-monitor > Disable

3. **App Still Works**
   - Local `SceneTriggerScheduler` continues to work
   - Users can still manually trigger scenes

4. **Re-enable When Fixed**
```sql
-- Re-run setup_scene_trigger_cron.sql
```

## Troubleshooting

### Cron Job Not Running
```sql
-- Check if pg_cron extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- If not, enable it
CREATE EXTENSION pg_cron;
```

### Edge Function Errors
- Check logs in Dashboard
- Verify service role key is correct
- Test manually with curl
- Check database permissions

### Commands Not Executing
- Verify app has `SceneCommandExecutor` started
- Check MQTT connection
- Verify Realtime subscription is active
- Check app logs

### High Costs
- Check edge function call count
- Verify cleanup job is running
- Consider increasing cleanup frequency

## Success Criteria

✅ Cron job runs every minute
✅ Edge function executes successfully
✅ Commands created in database
✅ App receives and executes commands
✅ Scenes work when app is closed
✅ No errors in logs
✅ Within Supabase free tier

## Support Resources

- Full Guide: `SCENE_AUTOMATION_BACKEND_SETUP.md`
- Quick Start: `SCENE_AUTOMATION_QUICK_START.md`
- Implementation Details: `SCENE_AUTOMATION_IMPLEMENTATION_SUMMARY.md`
- Test Queries: `test_scene_automation.sql`

## Notes

- Keep service role key secret
- Monitor costs in Supabase Dashboard
- Backup database before major changes
- Test in staging environment first (if available)

---

**Deployment Date:** _______________
**Deployed By:** _______________
**Status:** _______________
**Notes:** _______________
