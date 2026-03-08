@echo off
echo ========================================
echo Supabase Configuration Helper
echo ========================================
echo.
echo This script will help you find your Supabase credentials
echo needed for setting up the scene trigger cron job.
echo.
echo ========================================
echo Step 1: Get Your Project Reference
echo ========================================
echo.
echo 1. Go to: https://supabase.com/dashboard
echo 2. Select your project
echo 3. Go to Settings ^> API
echo 4. Copy the "Project URL"
echo    Example: https://abcdefghijklmnop.supabase.co
echo    Your Project Ref is: abcdefghijklmnop (the part before .supabase.co)
echo.
set /p PROJECT_REF="Enter your Project Ref: "
echo.
echo ========================================
echo Step 2: Get Your Service Role Key
echo ========================================
echo.
echo 1. On the same page (Settings ^> API)
echo 2. Scroll down to "Project API keys"
echo 3. Copy the "service_role" key (NOT the anon key!)
echo    WARNING: Keep this key secret! Never commit it to git!
echo.
set /p SERVICE_ROLE_KEY="Enter your Service Role Key: "
echo.
echo ========================================
echo Your Configuration
echo ========================================
echo.
echo Project Ref: %PROJECT_REF%
echo Service Role Key: %SERVICE_ROLE_KEY:~0,20%...
echo.
echo Edge Function URL:
echo https://%PROJECT_REF%.supabase.co/functions/v1/scene-trigger-monitor
echo.
echo ========================================
echo Next Steps
echo ========================================
echo.
echo 1. Open: supabase_migrations/setup_scene_trigger_cron.sql
echo 2. Replace YOUR_PROJECT_REF with: %PROJECT_REF%
echo 3. Replace YOUR_SERVICE_ROLE_KEY with your actual key
echo 4. Run the SQL in Supabase Dashboard ^> SQL Editor
echo.
echo Or test the edge function now with curl:
echo.
echo curl -X POST ^
echo   -H "Authorization: Bearer %SERVICE_ROLE_KEY%" ^
echo   -H "Content-Type: application/json" ^
echo   https://%PROJECT_REF%.supabase.co/functions/v1/scene-trigger-monitor
echo.
pause
