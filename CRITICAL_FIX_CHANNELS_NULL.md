# 🚨 CRITICAL FIX: Channels Must Be NULL for Shutters

## ❌ The Problem

**Your database has a CHECK constraint that I violated:**

```sql
CHECK (
  (device_type IN ('relay', 'dimmer') AND channels BETWEEN 1 AND 16)
  OR
  (device_type IN ('shutter', 'sensor', 'other') AND channels IS NULL)
)
```

**What I did wrong:**
- I was setting `channels=1` for shutter devices
- The constraint requires `channels=NULL` for shutters
- This caused the INSERT/UPDATE to fail with a CHECK constraint violation

**Why you got "Device Setup Error":**
- The database rejected the device creation
- The error was hidden behind a generic message
- The actual error was a CHECK constraint violation

---

## ✅ What I Fixed

### **1. Database Function: `claim_device`**

**Updated to respect the CHECK constraint:**

```sql
-- For shutters/sensors/other: channels = NULL
-- For relays/dimmers: channels = p_channels (1-16)

IF p_device_type IN ('shutter', 'sensor', 'other') THEN
  v_final_channels := NULL;
ELSE
  v_final_channels := p_channels;
END IF;
```

**Now the function:**
- Sets `channels=NULL` for shutters
- Sets `channels=<actual count>` for relays/dimmers
- Sets `channel_count=1` for shutters (separate field I added)
- Respects the CHECK constraint

### **2. Database Function: `reclassify_as_shutter`**

**Updated to set channels=NULL when re-classifying:**

```sql
UPDATE devices
SET device_type = 'shutter',
    channels = NULL,  -- ← CRITICAL: Must be NULL
    channel_count = 1,
    updated_at = now()
WHERE topic_base = p_topic_base;
```

### **3. Error Messages**

**Updated to show actual database errors:**

**File**: `lib/screens/add_device_flow_screen.dart`

**Changes:**
- Added detailed error logging with error type and full message
- Changed generic "Invalid device configuration" to show actual error
- Now you'll see the exact CHECK constraint violation message

**Before:**
```
Invalid device configuration. Please try the setup process again.
```

**After:**
```
Invalid device configuration:

new row for relation "devices" violates check constraint "devices_channels_by_type_check"

Please try the setup process again.
```

### **4. Debug Logging**

**Added comprehensive error logging:**

```dart
debugPrint('❌ FULL ERROR DETAILS: $e');
debugPrint('❌ ERROR TYPE: ${e.runtimeType}');
debugPrint('❌ STACK TRACE: ${StackTrace.current}');
```

---

## 📋 Database Schema Summary

### **Devices Table Columns:**

| Column | Type | Nullable | Constraint |
|--------|------|----------|------------|
| `device_type` | TEXT | NO | Must be 'relay', 'dimmer', 'shutter', 'sensor', or 'other' |
| `channels` | INTEGER | NO | NULL for shutters/sensors/other, 1-16 for relays/dimmers |
| `channel_count` | INTEGER | NO | Actual channel count (1 for shutters) |
| `home_id` | UUID | YES | Must belong to user (RLS enforced) |
| `display_name` | TEXT | NO | Device name (required) |
| `owner_user_id` | UUID | NO | Must match auth.uid() (RLS enforced) |

### **CHECK Constraint:**

```sql
devices_channels_by_type_check:
  (device_type IN ('relay', 'dimmer') AND channels BETWEEN 1 AND 16)
  OR
  (device_type IN ('shutter', 'sensor', 'other') AND channels IS NULL)
```

### **RLS Policies:**

- User must be authenticated (`auth.uid()` not null)
- User must own the device (`owner_user_id = auth.uid()`)
- OR user must be a member of the home (`is_home_member(home_id)`)

---

## 🧪 Testing Instructions

### **Step 1: Delete Existing Device**

Delete any existing shutter device from the app and database.

### **Step 2: Re-Provision**

Provision the shutter device again through the app.

### **Step 3: Check Debug Logs**

**Look for these logs:**

✅ **Success logs:**
```
🪟 Detected shutter device from STATUS 8
🔍 Device type: shutter, channels: 2, channel_count: 1
🔄 Claiming device: Hbot_XXXXXX (type: shutter, channels: 2, channel_count: 1)
🪟 Seeding shutter_states for device: <id>
✅ Shutter state seeded successfully
✅ Device created successfully: <id>
```

❌ **Error logs (if still failing):**
```
❌ Error creating device: <error message>
❌ FULL ERROR DETAILS: <full error>
❌ ERROR TYPE: <error type>
```

### **Step 4: Verify Database**

Run this query in Supabase SQL Editor:

```sql
SELECT 
  id, 
  topic_base, 
  display_name, 
  device_type, 
  channels,        -- Should be NULL for shutters
  channel_count,   -- Should be 1 for shutters
  home_id,
  owner_user_id
FROM devices
WHERE topic_base = 'Hbot_XXXXXX';  -- Replace with your device topic
```

**Expected result:**
- `device_type` = `'shutter'`
- `channels` = `NULL` ← **CRITICAL**
- `channel_count` = `1`
- `home_id` = valid UUID
- `owner_user_id` = your user ID

### **Step 5: Verify Shutter State**

```sql
SELECT * FROM shutter_states WHERE device_id = '<device-id>';
```

**Expected result:**
- One row with `position`, `direction`, `target`, `updated_at`

### **Step 6: Verify UI**

Open device detail screen and verify:
- ✅ Window icon (🪟)
- ✅ Slider (0-100%)
- ✅ 3 buttons: Close, Stop, Open
- ❌ NO relay toggles

---

## 🔍 Troubleshooting

### **If you still get "Device Setup Error":**

1. **Check the error message** - It should now show the actual database error
2. **Check debug logs** - Look for the full error details
3. **Common issues:**

   **a) CHECK constraint violation:**
   ```
   new row for relation "devices" violates check constraint "devices_channels_by_type_check"
   ```
   → The `claim_device` function is still setting `channels` incorrectly
   → Verify the function was updated correctly

   **b) RLS policy violation:**
   ```
   new row violates row-level security policy
   ```
   → User is not authenticated
   → OR `home_id` doesn't belong to user
   → OR `owner_user_id` doesn't match `auth.uid()`

   **c) NOT NULL violation:**
   ```
   null value in column "display_name" violates not-null constraint
   ```
   → Device name is missing
   → Verify `defaultName` parameter is being passed

   **d) Foreign key violation:**
   ```
   insert or update on table "devices" violates foreign key constraint
   ```
   → `home_id` doesn't exist in `homes` table
   → OR user is not a member of that home

### **If provisioning succeeds but UI shows relay toggles:**

1. **Check device_type in database:**
   ```sql
   SELECT device_type FROM devices WHERE id = '<device-id>';
   ```
   → Should be `'shutter'`, not `'relay'`

2. **Check app routing logic:**
   - Open `lib/widgets/enhanced_device_control_widget.dart`
   - Verify it routes by `device.deviceType` from database
   - NOT by channel count or name

3. **Force refresh:**
   - Close and reopen the device detail screen
   - OR restart the app

---

## 📁 Files Modified

1. **Database Functions** (via Supabase API):
   - `claim_device` - Sets `channels=NULL` for shutters
   - `reclassify_as_shutter` - Sets `channels=NULL` when re-classifying

2. **Flutter App**:
   - `lib/screens/add_device_flow_screen.dart` - Better error messages
   - `lib/services/simplified_device_service.dart` - Better error logging

---

## 🎯 Key Takeaways

1. **Shutters MUST have `channels=NULL`** - This is enforced by CHECK constraint
2. **Use `channel_count` for actual count** - This is the field I added (always 1 for shutters)
3. **Always show actual database errors** - Don't hide them behind generic messages
4. **Verify schema before coding** - Check constraints, RLS policies, and column types

---

## 🚀 Next Steps

1. **Re-provision the device** and check debug logs
2. **If it fails**, copy the full error message and share it
3. **If it succeeds**, verify database shows `channels=NULL`
4. **Test the UI** to ensure shutter controls appear

---

## 📞 If Still Failing

**Share these details:**

1. **Full error message** from debug logs
2. **Database query results** for the device row
3. **User authentication status** (`auth.uid()`)
4. **Home membership** (is user a member of the selected home?)

**This will help identify the exact issue!**

