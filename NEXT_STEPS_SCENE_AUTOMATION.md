# Next Steps: Scene Automation Setup

## What You Need to Do Now

### 1. Deploy Edge Function ⭐ CRITICAL

**Name:** `scene-trigger-monitor`

**No secrets needed** - Supabase automatically provides:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

**Deploy:**
```bash
supabase functions deploy scene-trigger-monitor
```

Or manually via Dashboard:
1. Go to Edge Functions > Create Function
2. Name: `scene-trigger-monitor`
3. Copy code from `supabase/functions/scene-trigger-monitor/index.ts`
4. Deploy

### 2. Setup Cron Job ⭐ CRITICAL

**Get your credentials:**
```bash
# Run this to get your Project Ref and Service Role Key
get_supabase_config.bat
```

**Then:**
1. Open `supabase_migrations/setup_scene_trigger_cron.sql`
2. Replace `YOUR_PROJECT_REF` with your actual project ref
3. Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key
4. Run in Supabase Dashboard > SQL Editor

### 3. Test Edge Function

```bash
# Run this to test manually
test_edge_function_manually.bat
```

Or use curl:
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

### 4. Debug if Needed

```sql
-- Run in Supabase SQL Editor
\i debug_scene_automation.sql
```

This will show you:
- ✅ If cron is running
- ✅ If scenes are configured
- ✅ If commands are being created
- ✅ What's wrong if it's not working

### 5. Rebuild App

```bash
flutter pub get
flutter build apk --release
```

## Testing Your Setup

### Test 1: Manual Edge Function Call

```bash
# Should return JSON with success: true
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

### Test 2: Check Cron is Running

```sql
-- Should show runs every minute
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'scene-trigger-monitor')
ORDER BY start_time DESC
LIMIT 5;
```

### Test 3: Create Test Scene

1. Open your app
2. Create a scene
3. Add a device action (turn on a light)
4. Add time trigger for current time + 2 minutes
5. Enable the scene
6. Close app completely
7. Wait 2 minutes
8. Check database:
```sql
SELECT * FROM scene_commands WHERE executed = false;
```
9. Should see a command!
10. Open app
11. Command should execute immediately

## What's Already Done

✅ Database table created (`scene_commands`)
✅ Flutter service created (`SceneCommandExecutor`)
✅ App updated (`main.dart`)
✅ Edge function code ready
✅ Documentation complete

## What You Need to Do

1. ⏳ Deploy edge function
2. ⏳ Setup cron job
3. ⏳ Test
4. ⏳ Rebuild app

**Time needed: ~10 minutes**

## Common Issues

### Issue: No commands in scene_commands table

**Check:**
1. Is cron job created? `SELECT * FROM cron.job WHERE jobname = 'scene-trigger-monitor';`
2. Is edge function deployed? Check Supabase Dashboard > Edge Functions
3. Is scene enabled? `SELECT * FROM scenes WHERE is_enabled = true;`
4. Is trigger configured? `SELECT * FROM scene_triggers WHERE is_enabled = true;`

**Fix:**
Run `debug_scene_automation.sql` to find the issue.

### Issue: Commands created but not executing

**Check:**
1. Is app running? Open it!
2. Check app logs for: `🎬 SceneCommandExecutor:`
3. Is MQTT connected? Check app logs

**Fix:**
- Rebuild app: `flutter pub get && flutter build apk`
- Restart app
- Check MQTT connection

### Issue: Timezone problems

Edge function uses **UTC time**. Convert your local time to UTC.

Example:
- You want 7:00 PM EST (UTC-5)
- UTC time is 12:00 AM (midnight)
- Set trigger: `hour: 0, minute: 0`

## Quick Reference

### Edge Function Name
```
scene-trigger-monitor
```

### Cron Schedule
```
* * * * *  (every minute)
```

### Database Table
```
scene_commands
```

### Flutter Service
```
SceneCommandExecutor
```

### Files to Check
- `supabase/functions/scene-trigger-monitor/index.ts` - Edge function
- `lib/services/scene_command_executor.dart` - Flutter service
- `lib/main.dart` - Service initialization

### SQL Scripts
- `debug_scene_automation.sql` - Debug everything
- `test_scene_automation.sql` - Verify setup
- `setup_scene_trigger_cron.sql` - Create cron job

### Batch Scripts
- `get_supabase_config.bat` - Get credentials
- `test_edge_function_manually.bat` - Test edge function

## Success Checklist

- [ ] Edge function deployed
- [ ] Cron job created
- [ ] Cron job running (check logs)
- [ ] Test scene created
- [ ] Time trigger configured
- [ ] Device action added
- [ ] Scene enabled
- [ ] App closed
- [ ] Trigger time passed
- [ ] Command in database
- [ ] App opened
- [ ] Command executed
- [ ] Device responded

## Getting Help

**If stuck:**
1. Run `debug_scene_automation.sql`
2. Check `TROUBLESHOOTING_SCENE_AUTOMATION.md`
3. Check edge function logs in Supabase Dashboard
4. Check app logs for `🎬 SceneCommandExecutor:`

**Documentation:**
- Quick Start: `SCENE_AUTOMATION_QUICK_START.md`
- Full Setup: `SCENE_AUTOMATION_BACKEND_SETUP.md`
- Troubleshooting: `TROUBLESHOOTING_SCENE_AUTOMATION.md`
- All Docs: `SCENE_AUTOMATION_INDEX.md`

## Summary

**What you have:**
- ✅ Complete backend code
- ✅ Complete app code
- ✅ Complete documentation
- ✅ Debug tools
- ✅ Test scripts

**What you need:**
- ⏳ 10 minutes to deploy
- ⏳ Your Supabase credentials
- ⏳ Test scene to verify

**Result:**
- 🎉 Scenes work 24/7
- 🎉 Even when app is closed
- 🎉 Reliable automation
- 🎉 Happy users!

---

**Ready? Start with step 1: Deploy the edge function!** 🚀
