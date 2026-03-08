# Repeat Options Feature

## ✅ Feature Added

Time-based scene triggers now support repeat options:
- **Once only** - Trigger only once
- **Every day** - Trigger every day
- **Monday to Friday** - Weekdays only
- **Weekend** - Saturday and Sunday only
- **Custom** - Select specific days

## 📦 Changes Made

### 1. Added State Variables

```dart
String _selectedRepeat = 'Every day'; // Repeat option
List<int> _customDays = [1, 2, 3, 4, 5, 6, 7]; // Custom days

final List<String> _repeatOptions = [
  'Once only',
  'Every day',
  'Monday to Friday',
  'Weekend',
  'Custom',
];
```

### 2. Added Repeat UI

After the time picker, added:
- **Repeat selector** - Shows current repeat option
- **Custom days selector** - Shows when "Custom" is selected
- Day chips (Mon, Tue, Wed, Thu, Fri, Sat, Sun)

### 3. Updated Trigger Creation

```dart
// Get days based on repeat option
final days = _getDaysFromRepeatOption();

// Convert to UTC with selected days
final utcHourMinute = await timezoneService.buildTriggerUtcHourMinute(
  _selectedTime!.hour,
  _selectedTime!.minute,
  days, // ✅ Now uses selected days
);

// Store in database
final configJson = {
  'hour': utcHourMinute['hour'],
  'minute': utcHourMinute['minute'],
  'days': days, // ✅ Stores selected days
};
```

### 4. Added Helper Methods

#### `_getDaysFromRepeatOption()`
Converts repeat option to days array:
- Once only → Current weekday
- Every day → [1,2,3,4,5,6,7]
- Monday to Friday → [1,2,3,4,5]
- Weekend → [6,7]
- Custom → User-selected days

#### `_showRepeatOptions()`
Shows bottom sheet with repeat options

#### `_buildDayChip()`
Builds selectable day chips for custom selection

## 🎯 How It Works

### User Flow

1. **Select Time Based trigger**
2. **Pick time** (e.g., 2:00 PM)
3. **Tap "Repeat"** → Shows options
4. **Select repeat option**:
   - Once only
   - Every day
   - Monday to Friday
   - Weekend
   - Custom (shows day selector)
5. **If Custom**: Select specific days
6. **Save scene**

### Database Storage

```json
{
  "hour": 12,      // UTC hour
  "minute": 0,     // UTC minute
  "days": [1,2,3,4,5]  // Monday to Friday
}
```

### Edge Function Matching

The edge function checks:
1. Current UTC hour/minute matches trigger
2. Current day is in the days array
3. If both match → Execute scene!

## 📊 Examples

### Example 1: Every Day at 7:00 AM
```
User selects:
- Time: 7:00 AM Egypt
- Repeat: Every day

Stored in DB:
{
  "hour": 5,  // 7 AM Egypt = 5 AM UTC
  "minute": 0,
  "days": [1,2,3,4,5,6,7]
}

Triggers: Every day at 7:00 AM Egypt time
```

### Example 2: Weekdays at 6:00 PM
```
User selects:
- Time: 6:00 PM Egypt
- Repeat: Monday to Friday

Stored in DB:
{
  "hour": 16,  // 6 PM Egypt = 4 PM UTC
  "minute": 0,
  "days": [1,2,3,4,5]
}

Triggers: Monday-Friday at 6:00 PM Egypt time
```

### Example 3: Weekend at 9:00 AM
```
User selects:
- Time: 9:00 AM Egypt
- Repeat: Weekend

Stored in DB:
{
  "hour": 7,  // 9 AM Egypt = 7 AM UTC
  "minute": 0,
  "days": [6,7]
}

Triggers: Saturday & Sunday at 9:00 AM Egypt time
```

### Example 4: Custom Days
```
User selects:
- Time: 8:00 PM Egypt
- Repeat: Custom
- Days: Mon, Wed, Fri

Stored in DB:
{
  "hour": 18,  // 8 PM Egypt = 6 PM UTC
  "minute": 0,
  "days": [1,3,5]
}

Triggers: Monday, Wednesday, Friday at 8:00 PM Egypt time
```

### Example 5: Once Only
```
User selects:
- Time: 3:00 PM Egypt
- Repeat: Once only

Stored in DB:
{
  "hour": 13,  // 3 PM Egypt = 1 PM UTC
  "minute": 0,
  "days": [2]  // If today is Tuesday
}

Triggers: Only on Tuesday at 3:00 PM Egypt time
```

## 🎨 UI Components

### Repeat Selector
```
┌─────────────────────────────────┐
│ Repeat          Every day    >  │
└─────────────────────────────────┘
```

### Repeat Options Bottom Sheet
```
┌─────────────────────────────────┐
│ Repeat                          │
│                                 │
│ ○ Once only                     │
│ ✓ Every day                     │
│ ○ Monday to Friday              │
│ ○ Weekend                       │
│ ○ Custom                        │
└─────────────────────────────────┘
```

### Custom Days Selector
```
┌─────────────────────────────────┐
│ Select Days                     │
│                                 │
│ [Mon] [Tue] [Wed] [Thu]        │
│ [Fri] [Sat] [Sun]              │
└─────────────────────────────────┘
```

## 🧪 Testing

### Test 1: Every Day
1. Create scene
2. Select time: Current time + 2 min
3. Select repeat: Every day
4. Save
5. Wait 2 minutes
6. Scene should trigger

### Test 2: Weekdays Only
1. Create scene
2. Select time: Current time + 2 min
3. Select repeat: Monday to Friday
4. Save
5. If today is weekday → triggers
6. If today is weekend → doesn't trigger

### Test 3: Custom Days
1. Create scene
2. Select time: Current time + 2 min
3. Select repeat: Custom
4. Select: Mon, Wed, Fri
5. Save
6. Triggers only on Mon/Wed/Fri

### Test 4: Once Only
1. Create scene
2. Select time: Current time + 2 min
3. Select repeat: Once only
4. Save
5. Triggers once today
6. Won't trigger tomorrow

## 🔍 Verification

Check database after creating scene:

```sql
SELECT 
  s.name,
  st.config_json->>'hour' as utc_hour,
  st.config_json->>'minute' as utc_minute,
  st.config_json->'days' as days
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE st.kind = 'schedule'
ORDER BY st.created_at DESC
LIMIT 1;
```

Expected output:
```
name: "Morning Routine"
utc_hour: "5"
utc_minute: "0"
days: [1,2,3,4,5]
```

## 📝 Notes

### Days Format
- **1** = Monday
- **2** = Tuesday
- **3** = Wednesday
- **4** = Thursday
- **5** = Friday
- **6** = Saturday
- **7** = Sunday

### Once Only Behavior
- Stores current weekday in days array
- Will trigger once on that day
- To trigger again, user must edit scene and save

### Custom Days
- Must select at least 1 day
- Days are sorted automatically
- Stored as array in database

## ✨ Benefits

✅ Flexible scheduling options
✅ Weekday/weekend shortcuts
✅ Custom day selection
✅ Once-only option for one-time events
✅ Intuitive UI
✅ Works with timezone conversion

## 🚀 Deployment

No database changes needed! Just rebuild the app:

```bash
flutter pub get
flutter build apk --release
```

## 📚 Related Files

- `lib/screens/add_scene_screen.dart` - UI and logic
- `lib/services/timezone_service.dart` - Timezone conversion
- `supabase/functions/scene-trigger-monitor/index.ts` - Edge function (no changes)

---

**Status:** ✅ Complete and ready to use!
