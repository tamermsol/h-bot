# Timezone Fix Implementation

## Problem Fixed

**Before:** Scene triggers created at "12:00 PM Egypt time" were stored as `hour=12, minute=0` in the database, but the Edge Function runs in UTC, causing triggers to fire 2 hours off (at 10:00 AM Egypt time instead of 12:00 PM).

**After:** Scene triggers are now correctly converted from Egypt local time to UTC before storage, ensuring they fire at the exact time the user selected.

## Implementation

### 1. SQL Migration - Server Time RPC

**File:** `supabase_migrations/create_server_time_rpc.sql`

```sql
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'utc_now', (now() AT TIME ZONE 'utc')::text,
    'timezone', 'UTC'
  );
$$;
```

**Purpose:** Provides authoritative server time to all clients, preventing device clock drift issues.

**Usage:**
```dart
final response = await supabase.rpc('get_server_time');
final utcNow = DateTime.parse(response['utc_now']).toUtc();
```

### 2. Timezone Service

**File:** `lib/services/timezone_service.dart`

**Key Functions:**

#### `fetchServerUtcNow()`
```dart
Future<DateTime> fetchServerUtcNow() async {
  final response = await supabase.rpc('get_server_time');
  final utcNowStr = response['utc_now'] as String;
  return DateTime.parse(utcNowStr).toUtc();
}
```
- Fetches current time from database server (not device)
- Returns DateTime in UTC
- Fallback to device time if RPC fails

#### `buildTriggerUtcHourMinute()`
```dart
Future<Map<String, int>> buildTriggerUtcHourMinute(
  int selectedHour,
  int selectedMinute,
  List<int>? selectedDays,
) async {
  // 1. Get server UTC time
  final serverUtcNow = await fetchServerUtcNow();
  
  // 2. Convert to Egypt time (UTC+2)
  final egyptNow = utcToEgypt(serverUtcNow);
  
  // 3. Build next occurrence in Egypt time
  DateTime nextOccurrenceEgypt = DateTime(
    egyptNow.year,
    egyptNow.month,
    egyptNow.day,
    selectedHour,
    selectedMinute,
  );
  
  // 4. If time passed today, use tomorrow
  if (nextOccurrenceEgypt.isBefore(egyptNow)) {
    nextOccurrenceEgypt = nextOccurrenceEgypt.add(Duration(days: 1));
  }
  
  // 5. Convert to UTC
  final nextOccurrenceUtc = egyptToUtc(nextOccurrenceEgypt);
  
  // 6. Return UTC hour/minute
  return {
    'hour': nextOccurrenceUtc.hour,
    'minute': nextOccurrenceUtc.minute,
  };
}
```

**Conversion Logic:**
- Egypt timezone: UTC+2 (no DST as of 2023)
- `utcToEgypt()`: Add 2 hours
- `egyptToUtc()`: Subtract 2 hours

### 3. Scene Trigger Creation Update

**File:** `lib/screens/add_scene_screen.dart`

**Before:**
```dart
final configJson = {
  'hour': _selectedTime!.hour,  // ❌ Egypt local time
  'minute': _selectedTime!.minute,
  'days': [1, 2, 3, 4, 5, 6, 7],
};
```

**After:**
```dart
final timezoneService = TimezoneService();

// Convert Egypt time to UTC
final utcHourMinute = await timezoneService.buildTriggerUtcHourMinute(
  _selectedTime!.hour,
  _selectedTime!.minute,
  [1, 2, 3, 4, 5, 6, 7],
);

final configJson = {
  'hour': utcHourMinute['hour'],      // ✅ UTC time
  'minute': utcHourMinute['minute'],
  'days': [1, 2, 3, 4, 5, 6, 7],
};
```

## Example Conversion

### User selects: 12:00 PM Egypt time

**Step 1:** Get server time
```
Server UTC: 2024-01-15 10:00:00 UTC
Egypt time: 2024-01-15 12:00:00 EET (UTC+2)
```

**Step 2:** User selects 12:00 PM Egypt
```
Selected: 12:00 Egypt
```

**Step 3:** Build next occurrence
```
Next occurrence Egypt: 2024-01-15 12:00:00 EET
(If current time is before 12:00 PM, use today; otherwise tomorrow)
```

**Step 4:** Convert to UTC
```
Next occurrence UTC: 2024-01-15 10:00:00 UTC
```

**Step 5:** Store in database
```json
{
  "hour": 10,
  "minute": 0,
  "days": [1, 2, 3, 4, 5, 6, 7]
}
```

**Step 6:** Edge function checks at 10:00 UTC
```
Current UTC: 10:00
Trigger UTC: 10:00
✅ MATCH! Execute scene.
```

**Step 7:** User sees correct time
```
Egypt time: 12:00 PM ✅
```

## Database Storage

### scene_triggers.config_json

**Format:**
```json
{
  "hour": <UTC_HOUR>,      // 0-23 in UTC
  "minute": <UTC_MINUTE>,  // 0-59
  "days": [1, 2, 3, 4, 5, 6, 7]  // 1=Monday, 7=Sunday
}
```

**Example:**
```json
{
  "hour": 10,
  "minute": 30,
  "days": [1, 2, 3, 4, 5]  // Weekdays only
}
```

This triggers at:
- **UTC:** 10:30 AM
- **Egypt:** 12:30 PM

## Edge Function (No Changes Needed)

The edge function already works correctly with UTC:

```typescript
const now = new Date();
const currentHour = now.getHours();  // UTC hour
const currentMinute = now.getMinutes();  // UTC minute

// Compare with stored UTC values
if (triggerHour === currentHour && triggerMinute === currentMinute) {
  // ✅ Trigger matches!
}
```

## Display to User

When showing trigger time to user, convert back to Egypt time:

```dart
final timezoneService = TimezoneService();

// Get stored UTC values from database
final storedHour = trigger.configJson['hour'] as int;
final storedMinute = trigger.configJson['minute'] as int;

// Convert to Egypt time for display
final egyptTime = timezoneService.utcHourMinuteToEgypt(
  storedHour,
  storedMinute,
);

// Format for display
final displayTime = timezoneService.formatEgyptTime(
  egyptTime['hour']!,
  egyptTime['minute']!,
);

print(displayTime);  // "12:30 PM"
```

## Testing

### Test 1: Create Scene at Current Time + 2 Minutes

1. Note current Egypt time (e.g., 2:30 PM)
2. Create scene with trigger at 2:32 PM Egypt
3. Check database:
```sql
SELECT config_json FROM scene_triggers WHERE scene_id = 'YOUR_SCENE_ID';
```
4. Should see:
```json
{"hour": 12, "minute": 32, "days": [1,2,3,4,5,6,7]}
```
(12:32 UTC = 2:32 PM Egypt)

5. Wait 2 minutes
6. Scene should trigger at exactly 2:32 PM Egypt time

### Test 2: Verify Edge Function Logs

1. Create scene for specific time
2. Check edge function logs at trigger time
3. Should see:
```
🔍 Checking triggers at 12:32
✅ Trigger matched for scene "Test Scene"
```

### Test 3: Cross-Timezone Verification

1. Create scene at 11:00 PM Egypt (21:00 UTC)
2. Database should store: `hour: 21, minute: 0`
3. Edge function triggers at 21:00 UTC
4. User sees: 11:00 PM Egypt ✅

## Important Notes

### Egypt Timezone Assumption

**Current Implementation:** Assumes Egypt is UTC+2 (no DST)

**Why:** Egypt stopped observing DST in 2023

**If DST is needed:**
1. Add `timezone` package to `pubspec.yaml`
2. Use `tz.TZDateTime` with `Africa/Cairo` timezone
3. Update `TimezoneService` to use timezone package

### Days of Week Mapping

**Format:** 1=Monday, 2=Tuesday, ..., 7=Sunday

**Consistent across:**
- Flutter app (Dart `DateTime.weekday`)
- Database storage
- Edge function checking

### Server Time vs Device Time

**Always use server time** for trigger calculations to avoid:
- Device clock drift
- User manually changing device time
- Timezone configuration errors

## Deployment Steps

### 1. Deploy SQL Migration

```sql
-- Run in Supabase SQL Editor
\i supabase_migrations/create_server_time_rpc.sql
```

### 2. Update Flutter App

```bash
flutter pub get
flutter build apk --release
```

### 3. Test

1. Create test scene
2. Verify UTC conversion in database
3. Wait for trigger time
4. Confirm scene executes at correct Egypt time

### 4. Update Existing Triggers (Optional)

If you have existing triggers stored in Egypt time:

```sql
-- WARNING: This assumes existing triggers are in Egypt time (UTC+2)
-- and converts them to UTC

UPDATE scene_triggers
SET config_json = jsonb_set(
  jsonb_set(
    config_json,
    '{hour}',
    to_jsonb(((config_json->>'hour')::int - 2 + 24) % 24)
  ),
  '{converted}',
  'true'::jsonb
)
WHERE kind = 'schedule'
  AND config_json->>'converted' IS NULL;
```

**Better approach:** Ask users to recreate their scenes.

## Summary

✅ **Fixed:** Timezone conversion bug
✅ **Method:** Convert Egypt → UTC before storage
✅ **Storage:** UTC hour/minute in database
✅ **Display:** Convert UTC → Egypt for user
✅ **Edge Function:** Works with UTC (no changes)
✅ **Server Time:** Used as authoritative clock

**Result:** Scenes trigger at exactly the time users select in Egypt timezone! 🎉
