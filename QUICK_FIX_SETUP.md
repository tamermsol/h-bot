# Quick Fix: Setup Without pg_cron

## The Problem
- `scene_commands` table is empty
- Scenes don't trigger when app is closed
- pg_cron not available or not working

## The Solution (5 Minutes)

### Option A: GitHub Actions (Recommended)

**Step 1:** Add GitHub Secrets

1. Go to your GitHub repository
2. Click **Settings** > **Secrets and variables** > **Actions**
3. Click **"New repository secret"**
4. Add first secret:
   - Name: `SUPABASE_PROJECT_REF`
   - Value: Your project ref (e.g., `abcdefghijkl`)
   - Click "Add secret"
5. Add second secret:
   - Name: `SUPABASE_SERVICE_ROLE_KEY`
   - Value: Your service role key from Supabase Dashboard > Settings > API
   - Click "Add secret"

**Step 2:** Commit the Workflow File

The file `.github/workflows/scene-trigger.yml` is already created. Just commit and push:

```bash
git add .github/workflows/scene-trigger.yml
git commit -m "Add scene trigger automation"
git push
```

**Step 3:** Enable and Test

1. Go to your GitHub repository
2. Click **Actions** tab
3. Click **"Scene Trigger Monitor"** workflow
4. Click **"Run workflow"** > **"Run workflow"** button
5. Wait 10 seconds
6. Click on the workflow run to see logs
7. Should see "✅ Scene trigger check completed successfully"

**Done!** It will now run every minute automatically.

---

### Option B: Cron-job.org (No GitHub needed)

**Step 1:** Sign Up

1. Go to https://cron-job.org/en/signup/
2. Create free account
3. Verify email

**Step 2:** Create Cron Job

1. Login and click **"Create cronjob"**
2. Fill in:
   - **Title:** `Scene Trigger Monitor`
   - **Address:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor`
     - Replace `YOUR_PROJECT_REF` with your actual project ref
   - **Schedule:** Select **"Every 1 minute"**
   - **Request method:** **POST**
   
3. Click **"Advanced"** tab
4. Under **"Headers"**, click **"Add header"**:
   - **Name:** `Authorization`
   - **Value:** `Bearer YOUR_SERVICE_ROLE_KEY`
     - Replace `YOUR_SERVICE_ROLE_KEY` with your actual key
   
5. Click **"Create cronjob"**

**Step 3:** Test

1. Find your cron job in the list
2. Click **"Run now"** button (play icon)
3. Click **"History"** tab
4. Should see successful execution with status 200

**Done!** It will run every minute automatically.

---

## How to Get Your Credentials

### Project Ref
1. Go to Supabase Dashboard
2. Look at your URL: `https://app.supabase.com/project/YOUR_PROJECT_REF`
3. Or go to Settings > API
4. Copy the part before `.supabase.co` in "Project URL"

Example: If URL is `https://abcdefghijkl.supabase.co`, your ref is `abcdefghijkl`

### Service Role Key
1. Go to Supabase Dashboard
2. Settings > API
3. Scroll to "Project API keys"
4. Copy the **"service_role"** key (NOT the anon key!)
5. ⚠️ Keep this secret! Never commit to git!

---

## Verify It's Working

### 1. Check Edge Function Logs (Immediate)

1. Supabase Dashboard > Edge Functions
2. Click **"scene-trigger-monitor"**
3. Click **"Logs"** tab
4. Should see new logs every minute

### 2. Create Test Scene

1. Open your app
2. Create a scene
3. Add a device action (turn on a light)
4. Add time trigger for **current time + 2 minutes**
5. Enable the scene
6. Note the time

### 3. Close App and Wait

1. **Fully close your app** (swipe away from recent apps)
2. Wait for the trigger time to pass
3. Wait 1 more minute (for cron to run)

### 4. Check Database

```sql
-- Run in Supabase SQL Editor
SELECT 
  sc.*,
  s.name as scene_name
FROM scene_commands sc
LEFT JOIN scene_runs sr ON sr.id = sc.scene_run_id
LEFT JOIN scenes s ON s.id = sr.scene_id
ORDER BY sc.created_at DESC
LIMIT 5;
```

**Should see a command!** ✅

### 5. Open App

1. Open your app
2. Check logs for: `🎬 SceneCommandExecutor: Found X pending command(s)`
3. Command should execute immediately
4. Device should respond

---

## Troubleshooting

### No logs in edge function?

**Check:**
1. Is edge function deployed? (Supabase Dashboard > Edge Functions)
2. Is cron service running? (Check GitHub Actions or cron-job.org)
3. Are credentials correct?

**Fix:**
Test manually:
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

Should return JSON with `"success": true`

### Logs show "No enabled scenes"?

**Check:**
```sql
SELECT * FROM scenes WHERE is_enabled = true;
```

If empty, create a scene in your app.

### Logs show scenes but no commands?

**Check:**
```sql
-- Check if scene has triggers
SELECT 
  s.name,
  st.kind,
  st.config_json,
  st.is_enabled
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE s.is_enabled = true;
```

**Check:**
```sql
-- Check if scene has device actions
SELECT 
  s.name,
  ss.action_json
FROM scene_steps ss
JOIN scenes s ON s.id = ss.scene_id
WHERE s.is_enabled = true;
```

If empty, edit scene and add device actions.

### Commands created but not executing?

**Check app logs:**
```
🎬 SceneCommandExecutor: Starting...
🎬 SceneCommandExecutor: Checking for pending commands...
```

If not present:
1. Rebuild app: `flutter pub get && flutter build apk`
2. Reinstall app
3. Check MQTT is connected

---

## Summary

**What you need:**
1. ✅ Edge function deployed (you have this)
2. ✅ scene_commands table created (you have this)
3. ⏳ Cron service calling edge function every minute (set this up now!)

**Choose one:**
- **GitHub Actions** - Free, reliable, version controlled
- **Cron-job.org** - Free, easy, no code needed

**Time:** 5 minutes

**Result:** Scenes work 24/7, even when app is closed! 🎉

---

## Next Steps

1. Choose GitHub Actions or Cron-job.org
2. Follow the steps above
3. Test with a scene
4. Enjoy automated scenes!

**Need help?** Check `TROUBLESHOOTING_SCENE_AUTOMATION.md`
