@echo off
echo ============================================
echo  Open Supabase SQL Editor
echo ============================================
echo.
echo This will open your Supabase SQL Editor in your browser.
echo.
echo Steps to fix the "column not found" error:
echo.
echo 1. The SQL Editor will open in your browser
echo 2. Click "New Query"
echo 3. Copy the contents of: run_this_migration.sql
echo 4. Paste into the SQL Editor
echo 5. Click "Run" or press Ctrl+Enter
echo 6. You should see "Success" message
echo.
echo Press any key to open Supabase Dashboard...
pause > nul

start https://supabase.com/dashboard/project/_/sql

echo.
echo ============================================
echo  SQL Editor should now be open!
echo ============================================
echo.
echo Don't forget to:
echo 1. Run the migration SQL
echo 2. Run: setup_backgrounds.bat
echo 3. Run: flutter pub get
echo 4. Hot restart your app
echo.
pause
