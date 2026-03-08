@echo off
echo ============================================
echo  Run Database Migration - Fix Column Error
echo ============================================
echo.
echo This will open your Supabase SQL Editor.
echo.
echo YOUR SUPABASE PROJECT:
echo URL: https://mvmvqycvorstsftcldzs.supabase.co
echo.
echo ============================================
echo  INSTRUCTIONS:
echo ============================================
echo.
echo 1. SQL Editor will open in your browser
echo 2. Click "New Query" button
echo 3. Copy ALL the SQL below (it's also in run_this_migration.sql)
echo 4. Paste into SQL Editor
echo 5. Click "Run" or press Ctrl+Enter
echo 6. Wait for "Success" message
echo.
echo ============================================
echo  SQL TO RUN:
echo ============================================
echo.
type run_this_migration.sql
echo.
echo ============================================
echo.
echo Press any key to open Supabase SQL Editor...
pause > nul

start https://supabase.com/dashboard/project/mvmvqycvorstsftcldzs/sql

echo.
echo ============================================
echo  SQL Editor is now open!
echo ============================================
echo.
echo NEXT STEPS:
echo 1. Copy the SQL from run_this_migration.sql
echo 2. Paste into SQL Editor
echo 3. Click Run
echo 4. Come back here when done
echo.
pause
