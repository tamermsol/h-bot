# Troubleshooting Scene Automation

## Quick Diagnosis

Run these steps in order to find the issue:

### Step 1: Run Debug Script

```sql
-- In Supabase Dashboard > SQL Editor
-- Copy and run: debug_scene_automation.sql
```

This will check:
- ✅ pg_cron extension enabled
- ✅ Cron job exists
- ✅ Cron job is running
- ✅ Scenes exist
- ✅ Triggers configured
- ✅ Device actions configured
- ✅ Commands being created

### Step 2: Test Edge Function Manually

```bash
# Run: test_edge_function_manually.bat
# Or use curl:

curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

Expected response:
```json
{
  "success": true,
  "timestamp": "2024-01-01T12:00:00.000Z",
  "triggered_scenes": [],
  "message": "Processed X scene(s), triggered Y"
}
```

## Common Issues & Solutions

### Issue 1: No Commands in scene_commands Table

**Symptoms:**
- Scene created with time trigger
- Time has passed
- No rows in `scene_commands` table

**Diagnosis:**
```sql
-- Check if cron job exists
SELECT * FROM cron.job WHERE jobname = 'scene-trigger-monitor';
```

**Solutions:**

#### A. Cron Job Not Created
```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create the cron job (update YOUR_PROJECT_REF and YOUR_SERVICE_ROLE_KEY)
SELECT cron.schedule(
  'scene-trigger-monitor',
  '* * * * *',
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

#### B. Edge Function Not Deployed
```bash
# Deploy the edge function
supabase functions deploy scene-trigger-monitor
```

#### C. Cron Job Running But No Commands

Check edge function logs:
1. Go to Supabase Dashboard
2. Edge Functions > scene-trigger-monitor
3. Click "Logs" tab
4. Look for errors

Common errors:
- "No enabled scenes found" → Enable your scene
- "Invalid trigger config" → Check trigger configuration
- "Device not found" → Check device exists

### Issue 2: Commands Created But Not Executing

**Symptoms:**
- Rows in `scene_commands` table with `executed = false`
- App is open
- Devices not responding

**Diagnosis:**
```sql
-- Check pending commands
SELECT * FROM scene_commands WHERE executed = false;
```

**Solutions:**

#### A. App Not Listening
Check app logs for:
```
🎬 SceneCommandExecutor: Starting...
🎬 SceneCommandExecutor: Started successfully
```

If not present:
1. Verify `lib/services/scene_command_executor.dart` exists
2. Verify `lib/main.dart` has `_sceneCommandExecutor.start()`
3. Rebuild app: `flutter pub get && flutter build apk`

#### B. Realtime Not Connected
Check app logs for:
```
🎬 SceneCommandExecutor: New command received
```

If not present:
- Check internet connection
- Verify Supabase Realtime is enabled
- Check RLS policies on `scene_commands` table

#### C. MQTT Not Connected
Check app logs for MQTT connection:
```
MQTT: Connected
```

If not connected:
- Verify MQTT broker is running
- Check device credentials
- Verify network connectivity

### Issue 3: Scene Trigger Time Not Matching

**Symptoms:**
- Scene should trigger at 7:00 PM
- Edge function runs but doesn't trigger scene

**Diagnosis:**
```sql
-- Check current time vs trigger time
SELECT 
  s.name,
  st.config_json->>'hour' as trigger_hour,
  st.config_json->>'minute' as trigger_minute,
  EXTRACT(HOUR FROM NOW()) as current_hour,
  EXTRACT(MINUTE FROM NOW()) as current_minute
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule';
```

**Solutions:**

#### A. Timezone Mismatch
Edge function uses UTC time. Convert your local time to UTC.

Example:
- Local time: 7:00 PM EST (UTC-5)
- UTC time: 12:00 AM (midnight)
- Set trigger: hour=0, minute=0

#### B. Day of Week Mismatch
```sql
-- Check day configuration
SELECT 
  s.name,
  st.config_json->'days' as trigger_days,
  CASE 
    WHEN EXTRACT(DOW FROM NOW()) = 0 THEN 7
    ELSE EXTRACT(DOW FROM NOW())
  END as current_day
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule';
```

Days: 1=Monday, 2=Tuesday, ..., 7=Sunday

### Issue 4: Device Actions Not Configured

**Symptoms:**
- Scene created
- No device actions in scene

**Diagnosis:**
```sql
-- Check scene steps
SELECT 
  s.name,
  ss.step_order,
  ss.action_json
FROM scene_steps ss
JOIN scenes s ON s.id = ss.scene_id
WHERE s.id = 'YOUR_SCENE_ID';
```

**Solution:**
1. Open app
2. Edit scene
3. Add device actions
4. Save scene

### Issue 5: Invalid Action JSON

**Symptoms:**
- Commands created
- Error in logs: "Invalid action data"

**Diagnosis:**
```sql
-- Check action_json structure
SELECT 
  ss.action_json
FROM scene_steps ss
WHERE ss.scene_id = 'YOUR_SCENE_ID';
```

**Expected format:**

For power (relay/dimmer):
```json
{
  "device_id": "uuid",
  "type": "power",
  "channels": [1, 2],
  "state": true
}
```

For shutter:
```json
{
  "device_id": "uuid",
  "type": "shutter",
  "position": 50
}
```

**Solution:**
If format is wrong, recreate the scene in the app.

### Issue 6: RLS Policies Blocking Access

**Symptoms:**
- Edge function runs
- No commands created
- Error in logs: "permission denied"

**Diagnosis:**
```sql
-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'scene_commands';
```

**Solution:**
```sql
-- Ensure service role can insert
CREATE POLICY "Service role can insert scene commands"
  ON public.scene_commands
  FOR INSERT
  WITH CHECK (true);
```

### Issue 7: App Closed, Commands Not Executing

**Symptoms:**
- App was closed
- Commands created in database
- Open app
- Commands still not executing

**Diagnosis:**
Check app logs when opening:
```
🎬 SceneCommandExecutor: Checking for pending commands...
🎬 SceneCommandExecutor: Found X pending command(s)
```

**Solutions:**

#### A. Not Processing Pending Commands
Verify `_processPendingCommands()` is called in `start()` method.

#### B. Commands Already Marked as Executed
```sql
-- Check command status
SELECT 
  id,
  executed,
  executed_at,
  error_message
FROM scene_commands
ORDER BY created_at DESC
LIMIT 10;
```

If `executed = true` but device didn't respond:
- Check MQTT connection
- Check device is online
- Check device topic_base is correct

## Verification Checklist

Use this checklist to verify everything is working:

### Backend Setup
- [ ] pg_cron extension enabled
- [ ] Edge function deployed
- [ ] Cron job created and active
- [ ] Cron job running every minute
- [ ] Edge function logs show executions

### Database Setup
- [ ] scene_commands table exists
- [ ] RLS policies configured
- [ ] Scenes exist and enabled
- [ ] Scene triggers configured
- [ ] Scene steps (device actions) configured

### App Setup
- [ ] SceneCommandExecutor service exists
- [ ] Service started in main.dart
- [ ] App rebuilt with new code
- [ ] MQTT connected
- [ ] Realtime subscription active

### End-to-End Test
- [ ] Create test scene
- [ ] Add device action
- [ ] Add time trigger (current time + 2 min)
- [ ] Close app completely
- [ ] Wait for trigger time
- [ ] Check database for command
- [ ] Open app
- [ ] Command executes
- [ ] Device responds

## Debug Queries

### Check Everything
```sql
-- Run the complete debug script
\i debug_scene_automation.sql
```

### Check Cron Status
```sql
SELECT 
  jobid,
  jobname,
  schedule,
  active
FROM cron.job
WHERE jobname = 'scene-trigger-monitor';
```

### Check Recent Cron Runs
```sql
SELECT 
  start_time,
  end_time,
  status,
  return_message
FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'scene-trigger-monitor')
ORDER BY start_time DESC
LIMIT 10;
```

### Check Pending Commands
```sql
SELECT 
  sc.*,
  s.name as scene_name
FROM scene_commands sc
LEFT JOIN scene_runs sr ON sr.id = sc.scene_run_id
LEFT JOIN scenes s ON s.id = sr.scene_id
WHERE sc.executed = false
ORDER BY sc.created_at DESC;
```

### Check Scene Configuration
```sql
SELECT 
  s.id,
  s.name,
  s.is_enabled,
  COUNT(DISTINCT st.id) as trigger_count,
  COUNT(DISTINCT ss.id) as step_count
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id AND st.is_enabled = true
LEFT JOIN scene_steps ss ON ss.scene_id = s.id
GROUP BY s.id, s.name, s.is_enabled;
```

### Check Device Topics
```sql
SELECT 
  d.id,
  d.display_name,
  d.topic_base,
  d.device_type,
  d.online
FROM devices d
WHERE d.id IN (
  SELECT DISTINCT (ss.action_json->>'device_id')::uuid
  FROM scene_steps ss
);
```

## Getting Help

If you're still stuck:

1. **Collect Information:**
   - Run `debug_scene_automation.sql`
   - Check edge function logs
   - Check app logs
   - Note any error messages

2. **Check Documentation:**
   - `SCENE_AUTOMATION_BACKEND_SETUP.md`
   - `SCENE_AUTOMATION_IMPLEMENTATION_SUMMARY.md`

3. **Common Fixes:**
   - Redeploy edge function
   - Recreate cron job
   - Rebuild app
   - Restart MQTT connection

## Quick Fixes

### Reset Everything
```sql
-- Delete all pending commands
DELETE FROM scene_commands WHERE executed = false;

-- Restart cron job
SELECT cron.unschedule('scene-trigger-monitor');
-- Then recreate it (see setup_scene_trigger_cron.sql)
```

### Force Manual Trigger
```bash
# Manually trigger edge function
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

### Test Command Insertion
```sql
-- Manually insert a test command
INSERT INTO scene_commands (
  device_id,
  topic_base,
  action_type,
  action_data,
  executed
)
SELECT 
  d.id,
  d.topic_base,
  'power',
  jsonb_build_object(
    'device_id', d.id,
    'type', 'power',
    'channels', ARRAY[1],
    'state', true
  ),
  false
FROM devices d
WHERE d.device_type = 'relay'
LIMIT 1;

-- Check if app picks it up
```

## Success Indicators

You know it's working when:

✅ Cron job runs every minute
✅ Edge function logs show "Processed X scene(s)"
✅ Commands appear in scene_commands table
✅ App logs show "New command received"
✅ Devices respond to commands
✅ Commands marked as executed
✅ Scenes work when app is closed

---

**Still having issues?** Check the edge function logs first - they usually tell you exactly what's wrong!
