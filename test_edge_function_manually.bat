@echo off
echo ========================================
echo Manual Edge Function Test
echo ========================================
echo.
echo This will manually trigger the edge function to test if it works.
echo.
set /p PROJECT_REF="Enter your Project Ref (e.g., abcdefgh): "
set /p SERVICE_ROLE_KEY="Enter your Service Role Key: "
echo.
echo Testing edge function...
echo.

curl -X POST ^
  -H "Authorization: Bearer %SERVICE_ROLE_KEY%" ^
  -H "Content-Type: application/json" ^
  https://%PROJECT_REF%.supabase.co/functions/v1/scene-trigger-monitor

echo.
echo.
echo ========================================
echo Check the response above
echo ========================================
echo.
echo Expected response:
echo {
echo   "success": true,
echo   "timestamp": "...",
echo   "triggered_scenes": [...],
echo   "message": "Processed X scene(s), triggered Y"
echo }
echo.
echo If you see an error, check:
echo 1. Edge function is deployed
echo 2. Service role key is correct
echo 3. Project ref is correct
echo.
pause
