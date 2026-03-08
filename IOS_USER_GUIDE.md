# iPhone User Guide - Adding Devices

## Quick Start

When adding a device on iPhone, you'll need to manually connect to the device's WiFi network. Here's how:

### Step 1: Enter Your WiFi Info
1. Open the HBOT app
2. Tap "Add Device"
3. Enter your home WiFi name and password
4. Tap "Next"

### Step 2: Connect to Device (Manual)
You'll see instructions to:

1. **Put device in pairing mode**
   - Press and hold the button on your device
   - Wait until the LED blinks rapidly

2. **Open iPhone Settings**
   - Press the Home button or swipe up
   - Tap the "Settings" app

3. **Go to WiFi**
   - Tap "WiFi" in Settings

4. **Find your device**
   - Look for a network starting with "hbot-"
   - Example: "hbot-1234"

5. **Connect**
   - Tap the hbot network
   - No password needed
   - Wait for checkmark to appear

6. **Return to HBOT app**
   - Swipe up and select HBOT app
   - Tap "I'm Connected"

### Step 3: Grant Permission
When you tap "I'm Connected", iPhone will ask:

```
"HBOT" Would Like to Find and Connect to 
Devices on Your Local Network
```

**Important:** Tap "OK" to allow this. The app needs this permission to configure your device.

### Step 4: Wait for Setup
- The app will send your WiFi info to the device
- Device will restart (LED will stop blinking)
- Device will connect to your home WiFi

### Step 5: Reconnect iPhone (if needed)
If the app asks, reconnect your iPhone to your home WiFi:
1. Open Settings > WiFi
2. Select your home WiFi network
3. Return to HBOT app

### Step 6: Done!
Your device is now added and ready to use!

## Troubleshooting

### "Not connected to device network"
- Go back to Settings > WiFi
- Make sure you're connected to the hbot-XXXX network
- Return to app and tap "I'm Connected" again

### "Timeout connecting to device"
- You may have tapped "Don't Allow" on the permission
- Fix: Go to Settings > HBOT > Local Network
- Turn it ON
- Return to app and try again

### "Device not found after setup"
- Your iPhone might still be on the device network
- Go to Settings > WiFi
- Connect to your home WiFi
- Return to app

### Device LED not blinking
- Device not in pairing mode
- Press and hold the button for 5-10 seconds
- LED should start blinking rapidly

### Can't find hbot-XXXX network
- Device might not be in pairing mode
- Try resetting the device
- Move closer to the device
- Make sure device is powered on

## Why Manual Connection?

Apple requires manual WiFi connection for security and privacy. Unlike Android, iPhone apps cannot:
- Scan for WiFi networks automatically
- Connect to WiFi networks automatically

This is an Apple restriction, not an app limitation.

## Permissions Explained

### Location Permission
- **When:** First time you open the app
- **Why:** Required by Apple to read WiFi network names
- **Choose:** "Allow While Using App"

### Local Network Permission  
- **When:** When you tap "I'm Connected" to device
- **Why:** Allows app to talk to devices on your WiFi
- **Choose:** "OK"

Both permissions are required for device setup to work.

## Tips

- Keep your iPhone close to the device during setup
- Make sure your home WiFi is 2.4GHz (not 5GHz only)
- Write down the hbot-XXXX network name before switching to Settings
- Don't close the HBOT app - just switch to Settings and back

## Need Help?

If you're still having trouble:
1. Make sure device is in pairing mode (LED blinking)
2. Make sure you granted both permissions
3. Try restarting the device
4. Try restarting your iPhone
5. Contact support with screenshots of any error messages
