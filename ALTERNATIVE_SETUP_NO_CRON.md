# Alternative Setup (Without pg_cron)

## Problem
- pg_cron extension not available in your Supabase plan
- "Connection string is missing" error

## Solution: Use Database Webhooks + External Cron

We'll use a **free external cron service** to trigger the edge function every minute.

## Option 1: GitHub Actions (Recommended - Free)

### Step 1: Create GitHub Actions Workflow

Create this file in your repository: `.github/workflows/scene-trigger.yml`

```yaml
name: Scene Trigger Monitor

on:
  schedule:
    # Runs every minute
    - cron: '* * * * *'
  workflow_dispatch: # Allows manual trigger

jobs:
  trigger-scenes:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Edge Function
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}" \
            -H "Content-Type: application/json" \
            https://${{ secrets.SUPABASE_PROJECT_REF }}.supabase.co/functions/v1/scene-trigger-monitor
```

### Step 2: Add GitHub Secrets

1. Go to your GitHub repository
2. Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Add two secrets:
   - Name: `SUPABASE_PROJECT_REF`, Value: Your project ref (e.g., `abcdefgh`)
   - Name: `SUPABASE_SERVICE_ROLE_KEY`, Value: Your service role key

### Step 3: Enable Workflow

1. Commit and push the workflow file
2. Go to Actions tab in GitHub
3. Enable workflows if prompted
4. The workflow will run every minute automatically!

### Step 4: Test Manually

1. Go to Actions tab
2. Click "Scene Trigger Monitor"
3. Click "Run workflow"
4. Check the logs

---

## Option 2: Cron-job.org (Free, No Code)

### Step 1: Sign Up

1. Go to https://cron-job.org
2. Sign up for free account
3. Verify email

### Step 2: Create Cron Job

1. Click "Create cronjob"
2. Fill in:
   - **Title:** Scene Trigger Monitor
   - **Address:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor`
   - **Schedule:** Every 1 minute
   - **Request method:** POST
   - **Headers:** Click "Add header"
     - Name: `Authorization`
     - Value: `Bearer YOUR_SERVICE_ROLE_KEY`
   - **Enabled:** Yes

3. Click "Create cronjob"

### Step 3: Test

1. Click "Run now" button
2. Check execution log
3. Should see success response

---

## Option 3: EasyCron (Free Tier)

### Step 1: Sign Up

1. Go to https://www.easycron.com
2. Sign up for free account (25 cron jobs free)

### Step 2: Create Cron Job

1. Click "Add Cron Job"
2. Fill in:
   - **URL:** `https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor`
   - **Cron Expression:** `* * * * *` (every minute)
   - **HTTP Method:** POST
   - **HTTP Headers:**
     ```
     Authorization: Bearer YOUR_SERVICE_ROLE_KEY
     Content-Type: application/json
     ```
   - **Status:** Enabled

3. Click "Create"

### Step 3: Test

1. Click "Test" button
2. Check response
3. Should see success

---

## Option 4: Render Cron Jobs (Free)

### Step 1: Sign Up

1. Go to https://render.com
2. Sign up for free account

### Step 2: Create Cron Job

1. Click "New +"
2. Select "Cron Job"
3. Fill in:
   - **Name:** scene-trigger-monitor
   - **Command:** 
     ```bash
     curl -X POST -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
     ```
   - **Schedule:** `* * * * *`

4. Click "Create Cron Job"

---

## Verification

After setting up any option above:

### 1. Check Edge Function Logs

1. Go to Supabase Dashboard
2. Edge Functions > scene-trigger-monitor
3. Click "Logs"
4. Should see executions every minute

### 2. Check Scene Commands

```sql
-- Run in Supabase SQL Editor
SELECT * FROM scene_commands 
ORDER BY created_at DESC 
LIMIT 10;
```

Should see commands when triggers match!

### 3. Test End-to-End

1. Create a scene in your app
2. Add device action
3. Add time trigger for current time + 2 minutes
4. Enable scene
5. Close app
6. Wait 2 minutes
7. Check database - should see command
8. Open app - command executes!

---

## Recommended: GitHub Actions

**Why?**
- ✅ Completely free
- ✅ Reliable
- ✅ No external service needed
- ✅ Version controlled
- ✅ Easy to modify

**Setup time:** 5 minutes

---

## Troubleshooting

### GitHub Actions not running?

1. Check if workflows are enabled (Settings > Actions)
2. Check if secrets are set correctly
3. View workflow logs in Actions tab

### External cron not working?

1. Test edge function manually:
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/scene-trigger-monitor
```

2. Check service role key is correct
3. Check edge function is deployed

### Still no commands?

Run debug script:
```sql
-- In Supabase SQL Editor
\i debug_scene_automation.sql
```

---

## Summary

**You don't need pg_cron!** Use any of these free alternatives:

1. **GitHub Actions** (Recommended) - Free, reliable
2. **Cron-job.org** - Free, easy setup
3. **EasyCron** - Free tier available
4. **Render** - Free cron jobs

All work the same way: Call your edge function every minute.

**Next:** Choose one option and set it up (5 minutes)!
