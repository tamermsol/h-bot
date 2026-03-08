2# Scene Automation Quick Start

## What Changed?

Your scenes now work **even when the app is fully closed**! 🎉

### How It Works

1. **Edge Function** runs every minute on Supabase servers
2. Checks for scene triggers (time, location, sensor)
3. Creates commands in `scene_commands` table
4. Your app listens via **Realtime** and executes commands via MQTT
5. Works even if app was closed - commands queue up and execute when app opens

## Setup (5 Minutes)

### 1. Deploy Database Migration

```bash
# Run this SQL in Supabase Dashboard > SQL Editor
```

Copy and run: `supabase_migrations/create_scene_commands_table.sql`

### 2. Deploy Edge Function

**Option A: Supabase CLI**
```bash
supabase functions deploy scene-trigger-monitor
```

**Option B: Dashboard**
1. Go to Edge Functions > Create Function
2. Name: `scene-trigger-monitor`
3. Copy code from `supabase/functions/scene-trigger-monitor/index.ts`
4. Deploy

### 3. Setup Cron Job

**Get your credentials:**
```bash
get_supabase_config.bat
```

**Then run this SQL:**
1. Open `supabase_migrations/setup_scene_trigger_cron.sql`
2. Replace `YOUR_PROJECT_REF` and `YOUR_SERVICE_ROLE_KEY`
3. Run in Supabase Dashboard > SQL Editor

### 4. Test It!

```bash
# Test edge function manually
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

## App Changes

The app now includes:
- ✅ `SceneCommandExecutor` - Listens for commands from edge function
- ✅ Realtime subscription to `scene_commands` table
- ✅ Automatic execution of queued commands
- ✅ Processes pending commands on app startup

**No code changes needed in your app!** Just rebuild and deploy.

## Testing

1. Create a scene with a time trigger for 1 minute from now
2. Close the app completely
3. Wait for trigger time
4. Open app - scene should execute immediately!

## Monitoring

### Check if cron is running:
```sql
SELECT * FROM cron.job WHERE jobname = 'scene-trigger-monitor';
```

### View recent runs:
```sql
SELECT * FROM cron.job_run_details
ORDER BY start_time DESC LIMIT 10;
```

### View pending commands:
```sql
SELECT * FROM scene_commands WHERE executed = false;
```

### View edge function logs:
Supabase Dashboard > Edge Functions > scene-trigger-monitor > Logs

## Costs

**FREE** on Supabase free tier!
- 43,200 edge function calls/month (60/hour × 24 × 30)
- Free tier includes 500,000 calls/month
- Realtime included

## Troubleshooting

### Scenes not triggering?
1. Check edge function logs
2. Verify cron job is running
3. Check scene is enabled: `SELECT * FROM scenes WHERE is_enabled = true`

### Commands not executing?
1. Check app logs for "🎬 SceneCommandExecutor"
2. Verify MQTT is connected
3. Check pending commands: `SELECT * FROM scene_commands WHERE executed = false`

### Need help?
See full guide: `SCENE_AUTOMATION_BACKEND_SETUP.md`

## What's Next?

- ✅ Time-based triggers work automatically
- ✅ Location triggers work (handled by app)
- 🔜 State triggers (sensor-based) - coming soon!
- 🔜 Push notifications for scene execution
- 🔜 Scene execution history in app

Enjoy your automated smart home! 🏠✨
