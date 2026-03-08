# ✅ Shutter Device Provisioning Fix - COMPLETE

## 🎯 Problem Solved

Your shutter device ("Hbot-Shutter") was being detected as a **2-Channel Relay** and showing relay toggle buttons instead of shutter controls (slider + 3 buttons).

**Root Cause:**
1. The app detected shutter in Flutter code but never updated the database
2. Database schema was missing required tables and columns
3. Device type remained 'relay' in database even though app detected shutter
4. No automatic re-classification during provisioning

---

## ✅ Solution Implemented

### **A) Database Schema (COMPLETE)**

All 6 requirements from your checklist are now met:

1. ✅ **device_type** - TEXT column (supports 'shutter')
2. ✅ **devices.channel_count** - INTEGER column added
3. ✅ **devices.online** - BOOLEAN column added
4. ✅ **devices.last_seen_at** - TIMESTAMPTZ column added
5. ✅ **shutter_states table** - Created with columns:
   - `device_id` (PK, UUID, FK to devices.id)
   - `position` (INTEGER, 0-100)
   - `direction` (SMALLINT, -1/0/1)
   - `target` (INTEGER, 0-100)
   - `tilt` (INTEGER, nullable)
   - `updated_at` (TIMESTAMPTZ)
6. ✅ **device_shutters view** - Created (JOIN devices + shutter_states)
7. ✅ **RLS Policies** - All 5 policies created:
   - SELECT (users can view their own)
   - INSERT (users can insert their own)
   - UPDATE (users can update their own)
   - DELETE (users can delete their own)
   - Service role (full access)
8. ✅ **Helper Functions** - Created 3 functions:
   - `upsert_shutter_state(device_id, position, direction, target, tilt)`
   - `mark_device_online(device_id)`
   - `reclassify_as_shutter(topic_base)`
9. ✅ **Indexes** - Created for performance:
   - `idx_devices_device_type`
   - `idx_devices_topic_base`
   - `idx_devices_online`
   - `idx_shutter_states_device_id`

---

### **B) Provisioning Flow (COMPLETE)**

Updated the device provisioning to automatically detect and classify shutter devices:

#### **1. Device Model Updated**
- **File**: `lib/models/device.dart`
- **Changes**:
  - Added `channelCount` field (nullable INTEGER)
  - Added `online` field (nullable BOOLEAN)
  - Added `lastSeenAt` field (nullable DateTime)
  - Updated constructor and copyWith method
  - Regenerated JSON serialization

#### **2. Database Functions Updated**
- **Function**: `claim_device`
- **Changes**:
  - Added `p_device_type` parameter (default: 'relay')
  - Added `p_channel_count` parameter (nullable)
  - Now sets `device_type` and `channel_count` during device creation
  - Idempotent - safe to run multiple times

#### **3. Repository Layer Updated**
- **File**: `lib/repos/device_management_repo.dart`
- **Changes**:
  - Added `deviceType` parameter to `claimDevice()`
  - Added `channelCount` parameter to `claimDevice()`
  - Passes both to database RPC function

- **File**: `lib/repos/devices_repo.dart`
- **Changes**:
  - Added `deviceType` parameter to `createDeviceWithClaiming()`
  - Added `channelCount` parameter to `createDeviceWithClaiming()`
  - Forwards to device_management_repo

#### **4. Service Layer Updated**
- **File**: `lib/services/simplified_device_service.dart`
- **Changes**:
  - Enhanced `_determineDeviceType()` to check STATUS 8 data
  - Now detects shutters using `ChannelDetectionUtils.isShutterDevice()`
  - Sets `channelCount = 1` for shutter devices
  - Passes `deviceType` and `channelCount` to database
  - **NEW**: Added `_seedShutterState()` method to seed shutter_states table
  - Automatically calls `upsert_shutter_state` after creating shutter device
  - Parses initial position/direction/target from STATUS 8 if available

---

### **C) Detection Logic (ALREADY COMPLETE)**

The following files were already updated in previous work:

- **`lib/utils/channel_detection_utils.dart`**
  - `isShutterDevice()` - Detects shutters from STATUS 8
  - Checks for `StatusSNS.Shutter1`, `StatusSHT`, or `Shutter1` fields
  - Checks for `SetOption80 = 1` (shutter mode enabled)

- **`lib/services/device_discovery_service.dart`**
  - Enhanced STATUS 8 analysis during provisioning
  - Sets `isShutter` flag on TasmotaDeviceInfo

- **`lib/models/tasmota_device_info.dart`**
  - Added `isShutter` boolean field

- **`lib/screens/add_device_flow_screen.dart`**
  - Enhanced `_determineDeviceType()` to check `deviceInfo.isShutter`

---

### **D) UI Routing (ALREADY COMPLETE)**

- **`lib/widgets/enhanced_device_control_widget.dart`**
  - Already routes to `ShutterControlWidget` when `device.deviceType == DeviceType.shutter`
  - No relay toggles shown for shutter devices

- **`lib/widgets/shutter_control_widget.dart`**
  - Already implemented with slider + 3 buttons (Close, Stop, Open)
  - Fixed AppTheme property names
  - Fixed deprecated `withOpacity()` calls

---

## 🔄 How It Works Now

### **Provisioning Flow:**

1. **User provisions device** → App connects to device AP
2. **App requests STATUS 8** → Device responds with Tasmota status
3. **App analyzes STATUS 8**:
   - `ChannelDetectionUtils.isShutterDevice()` checks for `Shutter1` field
   - If found → `deviceType = 'shutter'`, `channelCount = 1`
   - If not found → `deviceType = 'relay'`, `channelCount = channels`
4. **App creates device in database**:
   - Calls `claim_device()` RPC with `device_type` and `channel_count`
   - Database sets `device_type='shutter'` and `channel_count=1`
5. **App seeds shutter_states**:
   - Calls `upsert_shutter_state()` with initial position/direction/target
   - Parses values from STATUS 8 if available, defaults to 0
6. **App registers device with MQTT** → Ready for control
7. **User opens device detail** → Shutter UI renders (slider + 3 buttons)

---

## 📋 Testing Checklist

### **Before Testing:**
1. Delete existing "Hbot-Shutter" device from app and database
2. Ensure device is in shutter mode (SetOption80 1)
3. Ensure device is powered on and accessible

### **Test Steps:**

#### **1. Provisioning Test**
- [ ] Provision the shutter device through the app
- [ ] Check debug logs for: `🪟 Detected shutter device from STATUS 8`
- [ ] Check debug logs for: `Device type: shutter, channels: 2, channel_count: 1`
- [ ] Check debug logs for: `🪟 Seeding shutter_states for device: <id>`

#### **2. Database Verification**
Run these queries in Supabase SQL Editor:

```sql
-- Check device type and channel_count
SELECT id, topic_base, display_name, device_type, channels, channel_count, online
FROM devices
WHERE topic_base = 'Hbot_XXXXXX';  -- Replace with your device topic

-- Expected: device_type='shutter', channel_count=1

-- Check shutter_states
SELECT * FROM shutter_states WHERE device_id = '<device-id>';

-- Expected: One row with position, direction, target, tilt, updated_at

-- Check device_shutters view
SELECT * FROM device_shutters WHERE device_id = '<device-id>';

-- Expected: One row with all device + shutter state data
```

#### **3. UI Verification**
- [ ] Open device detail screen
- [ ] Verify UI shows:
  - ✅ Window icon (🪟)
  - ✅ Slider (0-100%)
  - ✅ 3 buttons: Close, Stop, Open
  - ❌ NO "Channel 1" / "Channel 2" toggles
  - ❌ NO "All ON" / "All OFF" buttons

#### **4. MQTT Command Test**
Monitor MQTT traffic (use MQTT Explorer or app debug logs):

- [ ] Tap **Open** button → See `cmnd/<topic>/ShutterOpen1`
- [ ] Tap **Close** button → See `cmnd/<topic>/ShutterClose1`
- [ ] Tap **Stop** button → See `cmnd/<topic>/ShutterStop1`
- [ ] Move slider to **25%** → See `cmnd/<topic>/ShutterPosition1 25`
- [ ] Move slider to **75%** → See `cmnd/<topic>/ShutterPosition1 75`

#### **5. Telemetry Test**
- [ ] Use wall switch to move shutter
- [ ] Within ~1 second, verify UI updates with new position
- [ ] Check database: `updated_at` in shutter_states should update

---

## 📁 Files Modified

### **Database:**
- `supabase_migrations/add_shutter_support.sql` (CREATED)

### **Flutter App:**
1. `lib/models/device.dart` - Added channel_count, online, last_seen_at
2. `lib/models/device.g.dart` - Regenerated JSON serialization
3. `lib/repos/device_management_repo.dart` - Added deviceType, channelCount params
4. `lib/repos/devices_repo.dart` - Added deviceType, channelCount params
5. `lib/services/simplified_device_service.dart` - Enhanced detection + seeding

### **Already Modified (Previous Work):**
6. `lib/utils/channel_detection_utils.dart` - Shutter detection logic
7. `lib/services/device_discovery_service.dart` - STATUS 8 analysis
8. `lib/models/tasmota_device_info.dart` - Added isShutter field
9. `lib/screens/add_device_flow_screen.dart` - Enhanced device type determination
10. `lib/widgets/enhanced_device_control_widget.dart` - UI routing
11. `lib/widgets/shutter_control_widget.dart` - Shutter UI

---

## 🚀 Next Steps

1. **Test the provisioning flow** using the checklist above
2. **Verify database** shows correct device_type and channel_count
3. **Test MQTT commands** from the UI
4. **Test telemetry updates** from wall switch
5. **Report any issues** for further fixes

---

## 🎉 Summary

**The complete fix is now in place!**

Your app will now:
- ✅ Automatically detect shutter devices during provisioning
- ✅ Set `device_type='shutter'` and `channel_count=1` in database
- ✅ Seed `shutter_states` table with initial position
- ✅ Display shutter UI (slider + 3 buttons) instead of relay toggles
- ✅ Send correct MQTT commands (`ShutterOpen/Close/Stop/Position`)
- ✅ Update UI in real-time from telemetry

**Ready to test! 🚀**

