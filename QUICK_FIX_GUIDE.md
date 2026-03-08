# Quick Fix Guide - Shutter Device Detection

## 🚀 What Was Fixed

Your shutter device was showing as a **2-Channel Relay** with toggle buttons instead of a **Shutter** with slider controls.

**Root Cause**: The app wasn't analyzing the Tasmota STATUS 8 response to detect the `Shutter1` field.

**Solution**: Added automatic shutter detection during device provisioning.

---

## ✅ Changes Made

### Files Modified (5)

1. **`lib/utils/channel_detection_utils.dart`**
   - Added `isShutterDevice()` method
   - Modified `detectChannelCount()` to prioritize shutter detection

2. **`lib/services/device_discovery_service.dart`**
   - Enhanced STATUS 8 analysis during provisioning
   - Detects `Shutter1` field and sets `isShutter = true`

3. **`lib/models/tasmota_device_info.dart`**
   - Added `isShutter` boolean field
   - Updated `copyWith()` method

4. **`lib/screens/add_device_flow_screen.dart`**
   - Enhanced `_determineDeviceType()` to check `deviceInfo.isShutter`
   - Prioritizes hardware detection over name-based detection

5. **`lib/models/tasmota_device_info.g.dart`**
   - Auto-generated JSON serialization (via build_runner)

### Files Already Correct (2)

1. **`lib/widgets/enhanced_device_control_widget.dart`**
   - ✅ Already had shutter UI routing
   - ✅ Already imported `ShutterControlWidget`

2. **`lib/widgets/shutter_control_widget.dart`**
   - ✅ Already implemented with slider + 3 buttons

---

## 🧪 How to Test

### Step 1: Delete Existing Device
```
1. Open app
2. Go to Devices screen
3. Find "Hbot-Shutter" device
4. Delete it
```

### Step 2: Re-Provision Device
```
1. Tap "Add Device"
2. Connect to device AP (hbot-XXXXXX)
3. Follow provisioning flow
4. Name it "Living Room Shutter" (or any name with "shutter"/"blind")
5. Complete setup
```

### Step 3: Verify Detection
**Check debug logs for these messages:**
```
🪟 Found Shutter1 in StatusSNS
🪟 Detected SHUTTER device - returning 1 channel
🪟 Device detected as SHUTTER from STATUS 8
🪟 Device type determined as SHUTTER from device info
```

### Step 4: Verify UI
**Device should show:**
- ✅ Window icon (🪟)
- ✅ "1-Channel Device • Shutter"
- ✅ Slider (0-100%)
- ✅ Three buttons: Close, Stop, Open
- ❌ NO "Channel 1" / "Channel 2" toggles
- ❌ NO "All ON" / "All OFF" buttons

### Step 5: Test Controls
```
1. Tap "Open" → Shutter opens
2. Tap "Stop" → Shutter stops
3. Tap "Close" → Shutter closes
4. Drag slider to 50% → Shutter moves to 50%
```

---

## 🔍 Detection Logic

### Priority Order

1. **Hardware Detection** (NEW - Highest Priority)
   ```
   STATUS 8 → StatusSNS.Shutter1 exists?
   → YES: device_type = 'shutter', channels = 1
   ```

2. **Name Detection** (Fallback)
   ```
   Device name contains "shutter" or "blind"?
   → YES: device_type = 'shutter'
   ```

3. **Default** (Last Resort)
   ```
   → device_type = 'relay'
   ```

### What Gets Checked

**During Provisioning:**
```dart
// STATUS 8 response analysis
{
  "StatusSNS": {
    "Time": "2025-01-06T12:00:00",
    "Shutter1": {              // ← This field triggers shutter detection
      "Position": 50,
      "Direction": 0,
      "Target": 50
    }
  }
}
```

**Detection Checks:**
1. `StatusSNS.Shutter1` exists? → Shutter ✓
2. `StatusSHT` exists? → Shutter ✓
3. `SetOption80 == 1`? → Shutter ✓
4. Root level `Shutter1` exists? → Shutter ✓

---

## 📊 Expected MQTT Commands

### When User Taps "Open"
```
Topic: cmnd/hbot_XXXXXX/ShutterOpen1
Payload: (empty)
```

### When User Taps "Close"
```
Topic: cmnd/hbot_XXXXXX/ShutterClose1
Payload: (empty)
```

### When User Taps "Stop"
```
Topic: cmnd/hbot_XXXXXX/ShutterStop1
Payload: (empty)
```

### When User Sets Position to 50%
```
Topic: cmnd/hbot_XXXXXX/ShutterPosition1
Payload: 50
```

---

## 🐛 Common Issues

### Issue 1: Still Shows as Relay

**Cause**: Old device record in database

**Fix:**
```
1. Delete device from app
2. Re-provision device
3. Ensure Tasmota has SetOption80 1
```

### Issue 2: No Shutter Detection in Logs

**Cause**: Tasmota shutter mode not enabled

**Fix (Tasmota Console):**
```
SetOption80 1
ShutterRelay1 1
ShutterOpenDuration1 10
ShutterCloseDuration1 10
Restart 1
```

### Issue 3: Commands Not Working

**Cause**: Wrong MQTT topic or device offline

**Fix:**
```
1. Check connection status (green dot)
2. Verify device topic in database
3. Test with Tasmota console: ShutterPosition1 50
```

---

## 🎯 Quick Validation

### Database Check
```sql
SELECT name, device_type, channel_count 
FROM devices 
WHERE name LIKE '%Shutter%';
```

**Expected Result:**
```
name: Hbot-Shutter
device_type: shutter
channel_count: 1
```

### UI Check
- Device icon: 🪟 (window)
- Device type label: "1-Channel Device • Shutter"
- Controls: Slider + 3 buttons
- NO relay toggles

### MQTT Check
- Open MQTT debug sheet
- Tap "Open" button
- Look for: `cmnd/hbot_XXXXXX/ShutterOpen1`

---

## ✅ Success Criteria

All of these should be TRUE:

- [ ] Device detected as "shutter" type during provisioning
- [ ] Channel count is 1 (not 2)
- [ ] UI shows slider and 3 buttons
- [ ] UI does NOT show "Channel 1" / "Channel 2" toggles
- [ ] Tapping "Open" sends `ShutterOpen1` command
- [ ] Tapping "Close" sends `ShutterClose1` command
- [ ] Tapping "Stop" sends `ShutterStop1` command
- [ ] Dragging slider sends `ShutterPosition1` command
- [ ] Position updates in real-time

---

## 📚 Related Documentation

- **Full Implementation**: `SHUTTER_FIX_COMPLETE.md`
- **User Guide**: `SHUTTER_USER_GUIDE.md`
- **Technical Docs**: `SHUTTER_DEVICE_IMPLEMENTATION.md`
- **Quick Start**: `SHUTTER_QUICK_START.md`

---

## 🎉 Summary

**The fix is complete!** 

Your app now automatically detects shutter devices by analyzing the Tasmota STATUS 8 response during provisioning. When a device has the `Shutter1` field, it's classified as a shutter with 1 channel, and the UI automatically shows the shutter controls (slider + 3 buttons) instead of relay toggles.

**Next step**: Delete your existing "Hbot-Shutter" device and re-provision it to see the automatic detection in action!

