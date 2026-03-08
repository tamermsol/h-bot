@echo off
echo ============================================
echo  Rebuilding App with Edge-to-Edge Support
echo ============================================
echo.
echo This will:
echo 1. Clean the build
echo 2. Rebuild the app
echo 3. Install on connected device
echo.
echo Make sure your phone is connected via USB!
echo.
pause

echo.
echo Step 1: Cleaning build...
call flutter clean

echo.
echo Step 2: Getting dependencies...
call flutter pub get

echo.
echo Step 3: Building and installing...
call flutter run

echo.
echo ============================================
echo  Build Complete!
echo ============================================
echo.
echo The app should now have edge-to-edge background.
echo.
echo If it doesn't work:
echo 1. Uninstall the app from your phone
echo 2. Run this script again
echo.
pause
