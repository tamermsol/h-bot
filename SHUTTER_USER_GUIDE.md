# Shutter Device User Guide

## 🪟 Welcome to Shutter Control!

Your hbot smart home system now supports **smart shutter/blind control** with an intuitive interface designed for easy operation.

---

## 🎯 Quick Overview

### What You Can Do
- ✅ **Open** shutters fully with one tap
- ✅ **Close** shutters fully with one tap
- ✅ **Stop** shutters at any position
- ✅ **Set precise position** using a slider (0-100%)
- ✅ **Monitor position** in real-time
- ✅ **Check connection** status at a glance

---

## 📱 Control Interface

When you open a shutter device, you'll see this interface:

```
╔═══════════════════════════════════════╗
║  ● Connected                          ║
╠═══════════════════════════════════════╣
║                                       ║
║   ┌─────────┐  ┌─────────┐  ┌──────┐║
║   │    ↓    │  │   ║║    │  │   ↑  │║
║   │  Close  │  │  Stop   │  │ Open │║
║   └─────────┘  └─────────┘  └──────┘║
║                                       ║
╠═══════════════════════════════════════╣
║                                       ║
║              50%                      ║
║                                       ║
║   Close ━━━━━━●━━━━━━ Open          ║
║                                       ║
╚═══════════════════════════════════════╝
```

---

## 🔘 Button Controls

### 1. **Close Button** (Left)
- **Icon**: ↓ (Down arrow)
- **Action**: Closes shutter completely (0%)
- **Use**: When you want to fully close the shutter
- **Example**: "Close bedroom shutter for privacy"

### 2. **Stop Button** (Center - Highlighted)
- **Icon**: ║║ (Pause symbol)
- **Action**: Stops shutter immediately
- **Use**: When you want to stop at current position
- **Example**: "Stop at 60% for partial shade"

### 3. **Open Button** (Right)
- **Icon**: ↑ (Up arrow)
- **Action**: Opens shutter completely (100%)
- **Use**: When you want to fully open the shutter
- **Example**: "Open living room shutter for sunlight"

---

## 🎚️ Slider Control

### How to Use
1. **Tap and hold** the slider thumb (●)
2. **Drag left** to close (0%)
3. **Drag right** to open (100%)
4. **Release** to set position

### Position Guide
- **0%** = Fully Closed (no light)
- **25%** = Slightly Open (minimal light)
- **50%** = Half Open (moderate light)
- **75%** = Mostly Open (good light)
- **100%** = Fully Open (maximum light)

### Tips
- The percentage updates as you drag
- Release anywhere to set that exact position
- The shutter will move to the selected position
- Current position is shown above the slider

---

## 📊 Status Indicators

### Connection Status
- **● Green** = Connected to MQTT broker
- **● Red** = Disconnected (check internet)

### Moving Indicator
- **Spinner** appears when shutter is moving
- Disappears when shutter reaches position

### Position Display
- **Large number** shows current position (0-100%)
- Updates in real-time as shutter moves

---

## 📖 Common Use Cases

### Morning Routine
```
1. Wake up
2. Open app → Select bedroom shutter
3. Tap "Open" button
4. Shutter opens to let in sunlight
```

### Privacy Mode
```
1. Need privacy
2. Open app → Select room shutter
3. Tap "Close" button
4. Shutter closes completely
```

### Partial Shade
```
1. Too much sun
2. Open app → Select shutter
3. Drag slider to 40%
4. Shutter moves to 40% (partial shade)
```

### Stop Mid-Movement
```
1. Shutter is moving
2. You like current position
3. Tap "Stop" button
4. Shutter stops immediately
```

---

## 🔧 Setup Guide

### Step 1: Add Shutter Device

1. **Open hbot app**
2. Tap **"Add Device"** button
3. Follow **Wi-Fi setup** instructions
4. Connect to device network (hbot-XXXXXX)

### Step 2: Name Your Device

When prompted, name your device with "shutter" or "blind":
- ✅ "Living Room Shutter"
- ✅ "Bedroom Blind"
- ✅ "Kitchen Window Shutter"
- ✅ "Office Blind"

### Step 3: Complete Setup

1. Enter your **Wi-Fi password**
2. Wait for device to connect
3. Device will be **automatically detected** as shutter
4. Tap **"Done"** to finish

### Step 4: Start Controlling

1. Go to **Devices** screen
2. Find your shutter device
3. Tap to open control screen
4. Use buttons or slider to control!

---

## ⚙️ Device Configuration

### Tasmota Settings (Advanced)

If you have access to the Tasmota console:

```bash
# Enable shutter mode
SetOption80 1

# Configure timing (adjust for your shutter)
ShutterOpenDuration1 10    # Seconds to fully open
ShutterCloseDuration1 10   # Seconds to fully close

# Enable position reporting
ShutterReporting 1
```

### Calibration

For accurate position control:

```bash
# 1. Close shutter manually, then:
ShutterSetClose1

# 2. Open shutter manually, then:
ShutterSetOpen1

# 3. Test position
ShutterPosition1 50    # Should move to 50%
```

---

## 🐛 Troubleshooting

### Shutter Not Responding

**Problem**: Buttons don't work
**Check**:
- ✅ Connection status (should be green)
- ✅ Internet connection
- ✅ Device is powered on

**Solution**:
1. Check Wi-Fi connection
2. Restart app
3. Check device power

---

### Position Not Accurate

**Problem**: Shutter doesn't stop at correct position
**Cause**: Device needs calibration

**Solution**:
1. Access Tasmota console
2. Run calibration commands (see above)
3. Test with 50% position

---

### Connection Lost

**Problem**: Red dot shows "Disconnected"
**Check**:
- ✅ Internet connection
- ✅ Wi-Fi signal strength
- ✅ MQTT broker status

**Solution**:
1. Check internet connection
2. Move closer to Wi-Fi router
3. Restart app
4. Contact support if persists

---

### Shutter Stops Randomly

**Problem**: Shutter stops before reaching position
**Cause**: Timing not configured correctly

**Solution**:
1. Increase open/close duration in Tasmota
2. Check for physical obstructions
3. Recalibrate device

---

## 💡 Tips & Tricks

### Quick Actions
- **Double-tap Open** for maximum light
- **Double-tap Close** for complete privacy
- **Use slider** for precise control

### Energy Saving
- Close shutters at night to retain heat
- Open shutters during day for natural light
- Use 50% position for balanced temperature

### Automation Ideas
- **Morning**: Auto-open at sunrise
- **Evening**: Auto-close at sunset
- **Hot days**: Close to 40% for shade
- **Away mode**: Random positions for security

---

## 📞 Support

### Need Help?

**App Issues**:
- Check app version (latest recommended)
- Clear app cache
- Reinstall if necessary

**Device Issues**:
- Check Tasmota firmware version
- Verify shutter configuration
- Test with Tasmota console

**Connection Issues**:
- Verify MQTT broker status
- Check Wi-Fi signal strength
- Restart router if needed

---

## 🎓 Learn More

### Understanding Positions
- **0-25%**: Closed to slightly open
- **25-50%**: Partial opening
- **50-75%**: Mostly open
- **75-100%**: Nearly to fully open

### Best Practices
1. **Calibrate** device after installation
2. **Test** all positions before daily use
3. **Monitor** battery (if applicable)
4. **Update** firmware regularly

### Safety
- ⚠️ Don't force shutter manually while motor is running
- ⚠️ Keep fingers clear of moving parts
- ⚠️ Stop immediately if unusual sounds occur
- ⚠️ Regular maintenance recommended

---

## 📱 App Features

### Real-time Control
- Instant response to button presses
- Live position updates
- Connection status monitoring

### Smart Features
- Optimistic UI updates (instant feedback)
- Automatic reconnection
- Error recovery

### User-Friendly
- Simple, intuitive interface
- Clear visual feedback
- Easy to understand controls

---

## ✨ Enjoy Your Smart Shutters!

You now have complete control over your shutters with:
- ✅ **Easy button controls**
- ✅ **Precise slider positioning**
- ✅ **Real-time status updates**
- ✅ **Reliable MQTT communication**

**Happy controlling!** 🎉

---

*For technical documentation, see SHUTTER_DEVICE_IMPLEMENTATION.md*
*For quick setup, see SHUTTER_QUICK_START.md*

