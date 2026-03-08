# Scene Triggers Testing Guide

## Quick Start Testing

### Test 1: Create a Time-Based Scene

**Objective:** Verify that users can create scenes with time-based triggers

**Steps:**
1. Open the app and navigate to the Scenes screen
2. Tap the "+" button to create a new scene
3. **Step 1 - Basic Information:**
   - Enter scene name: "Test Morning Lights"
   - Tap "Next"
4. **Step 2 - Appearance:**
   - Select any icon and color
   - Tap "Next"
5. **Step 3 - Trigger:**
   - Select "Time Based" (should show time picker)
   - Tap "Select Time"
   - Choose a time **2 minutes from now**
   - Tap "OK"
   - Tap "Next"
6. **Step 4 - Devices:**
   - Select at least one device (e.g., a light)
   - Tap "Next"
7. **Step 5 - Actions:**
   - Configure the device action (e.g., turn on, brightness 100%)
   - Tap "Next"
8. **Step 6 - Review:**
   - Review the scene details
   - Tap "Create Scene"

**Expected Result:**
- ✅ Scene is created successfully
- ✅ Success message appears
- ✅ Scene appears in the scenes list
- ✅ Console shows: "Scene trigger created with hour: X, minute: Y"

**Database Verification:**
```sql
-- Check scene was created
SELECT * FROM scenes WHERE name = 'Test Morning Lights';

-- Check trigger was created
SELECT st.*, s.name 
FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE s.name = 'Test Morning Lights';

-- Verify config_json format
-- Should show: {"hour": X, "minute": Y, "days": [1,2,3,4,5,6,7]}
```

---

### Test 2: Verify Foreground Execution

**Objective:** Verify that scenes execute automatically at the scheduled time

**Prerequisites:**
- Complete Test 1 (scene created with trigger 2 minutes from now)
- App must be open (foreground or background, not terminated)

**Steps:**
1. Keep the app open
2. Watch the console logs
3. Wait for the scheduled time

**Expected Console Logs:**
```
⏰ SceneTriggerScheduler: Checking triggers at 14:32
⏰ SceneTriggerScheduler: Found 1 enabled scene(s)
⏰ SceneTriggerScheduler: Executing scene "Test Morning Lights" (trigger abc-123)
⏰ SceneTriggerScheduler: Running scene "Test Morning Lights"...
⏰ SceneTriggerScheduler: Scene "Test Morning Lights" executed successfully
```

**Expected Result:**
- ✅ Scene executes at the scheduled time
- ✅ Device action is performed (light turns on)
- ✅ Scene run is logged in database
- ✅ No errors in console

**Database Verification:**
```sql
-- Check scene run was created
SELECT sr.*, s.name, sr.status, sr.logs_json
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
WHERE s.name = 'Test Morning Lights'
ORDER BY sr.started_at DESC
LIMIT 1;

-- Should show status = 'success'
```

---

### Test 3: Edit Scene Trigger

**Objective:** Verify that users can edit existing scene triggers

**Steps:**
1. Navigate to Scenes screen
2. Find "Test Morning Lights" scene
3. Tap the "..." menu button
4. Select "Edit"
5. Navigate to Step 3 (Trigger)
6. Verify current trigger shows "Time Based" and the previously selected time
7. Tap "Select Time"
8. Choose a new time (3 minutes from now)
9. Tap "OK"
10. Navigate through remaining steps
11. Tap "Update Scene"

**Expected Result:**
- ✅ Scene is updated successfully
- ✅ Old trigger is deleted
- ✅ New trigger is created with updated time
- ✅ Console shows: "Scene trigger updated"

**Database Verification:**
```sql
-- Check only one trigger exists for the scene
SELECT COUNT(*) FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE s.name = 'Test Morning Lights';
-- Should return 1

-- Verify new time is saved
SELECT config_json FROM scene_triggers st
JOIN scenes s ON s.id = st.scene_id
WHERE s.name = 'Test Morning Lights';
-- Should show new hour and minute
```

---

### Test 4: Duplicate Execution Prevention

**Objective:** Verify that scenes don't execute multiple times in the same minute

**Steps:**
1. Create a scene with trigger time 2 minutes from now
2. Keep app open
3. Watch console logs carefully
4. Wait for trigger time
5. Continue watching for 1 more minute

**Expected Result:**
- ✅ Scene executes exactly once at the trigger time
- ✅ Console shows "Skipping duplicate execution" if checked again in same minute
- ✅ Only one scene run is created in database

**Console Logs to Look For:**
```
⏰ SceneTriggerScheduler: Executing scene "Test Scene" (trigger abc-123)
⏰ SceneTriggerScheduler: Skipping duplicate execution for scene "Test Scene" (trigger abc-123)
```

---

### Test 5: Multiple Scenes with Different Times

**Objective:** Verify that multiple scenes can have different trigger times

**Steps:**
1. Create Scene A with trigger at current time + 2 minutes
2. Create Scene B with trigger at current time + 3 minutes
3. Create Scene C with trigger at current time + 4 minutes
4. Keep app open
5. Watch console logs

**Expected Result:**
- ✅ Scene A executes at minute 2
- ✅ Scene B executes at minute 3
- ✅ Scene C executes at minute 4
- ✅ All scenes execute in correct order
- ✅ No interference between scenes

---

### Test 6: Disabled Scene Doesn't Execute

**Objective:** Verify that disabled scenes don't execute

**Steps:**
1. Create a scene with trigger time 2 minutes from now
2. Disable the scene (set `is_enabled = false` in database or via UI if available)
3. Wait for trigger time

**Expected Result:**
- ✅ Scene does NOT execute
- ✅ Console shows scene was found but skipped (if logging includes disabled scenes)
- ✅ No scene run is created

---

### Test 7: Scheduler Lifecycle

**Objective:** Verify that scheduler starts and stops correctly

**Steps:**
1. Launch the app
2. Check console logs for scheduler start message
3. Close the app completely
4. Reopen the app
5. Check console logs again

**Expected Console Logs:**
```
// On app launch
⏰ SceneTriggerScheduler: Starting...
⏰ SceneTriggerScheduler: Started successfully

// On app close
⏰ SceneTriggerScheduler: Stopping...
⏰ SceneTriggerScheduler: Stopped successfully

// On app relaunch
⏰ SceneTriggerScheduler: Starting...
⏰ SceneTriggerScheduler: Started successfully
```

**Expected Result:**
- ✅ Scheduler starts when app launches
- ✅ Scheduler stops when app closes
- ✅ No duplicate timers are created
- ✅ No memory leaks

---

### Test 8: Background Execution (App in Background)

**Objective:** Verify that scenes execute when app is in background

**Steps:**
1. Create a scene with trigger time 2 minutes from now
2. Press home button to send app to background (don't terminate)
3. Wait for trigger time
4. Reopen app
5. Check scene run history

**Expected Result:**
- ✅ Scene executed while app was in background
- ✅ Scene run appears in history
- ✅ Device action was performed

**Note:** This works because the foreground scheduler continues running when app is in background (but not terminated).

---

### Test 9: Validation - Time Required

**Objective:** Verify that time selection is required for time-based triggers

**Steps:**
1. Start creating a new scene
2. Navigate to Step 3 (Trigger)
3. Select "Time Based"
4. Do NOT select a time
5. Try to proceed to next step

**Expected Result:**
- ✅ Error message appears: "Please select an activation time for time-based trigger"
- ✅ Cannot proceed without selecting time
- ✅ User is prompted to select time

---

### Test 10: Daily Recurring Execution

**Objective:** Verify that scenes execute every day at the scheduled time

**Steps:**
1. Create a scene with trigger at a specific time (e.g., 9:00 AM)
2. Wait for the trigger time today
3. Verify scene executes
4. Wait until the same time tomorrow
5. Verify scene executes again

**Expected Result:**
- ✅ Scene executes today at 9:00 AM
- ✅ Scene executes tomorrow at 9:00 AM
- ✅ Scene continues to execute daily
- ✅ Each execution creates a new scene run record

**Database Verification:**
```sql
-- Check multiple scene runs for the same scene
SELECT sr.started_at, sr.status
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
WHERE s.name = 'Daily Morning Scene'
ORDER BY sr.started_at DESC;
-- Should show multiple runs on different days
```

---

## Advanced Testing

### Test 11: Stress Test - Many Scenes

**Objective:** Test performance with many scenes

**Steps:**
1. Create 50 scenes with different trigger times
2. Monitor app performance
3. Check memory usage
4. Verify all scenes execute correctly

**Expected Result:**
- ✅ App remains responsive
- ✅ Memory usage is reasonable
- ✅ All scenes execute at correct times
- ✅ No performance degradation

---

### Test 12: Edge Cases

#### Test 12a: Midnight Trigger
- Create scene with trigger at 00:00 (midnight)
- Verify it executes correctly

#### Test 12b: 23:59 Trigger
- Create scene with trigger at 23:59
- Verify it executes correctly

#### Test 12c: Same Time Multiple Scenes
- Create 5 scenes all with trigger at same time
- Verify all execute correctly

---

## Debugging Tips

### Enable Verbose Logging

All scheduler logs are prefixed with `⏰` for easy filtering.

**Android Studio / VS Code:**
```
Filter: ⏰
```

### Check Database State

```sql
-- List all scenes with triggers
SELECT 
    s.name,
    s.is_enabled,
    st.kind,
    st.config_json,
    st.is_enabled as trigger_enabled
FROM scenes s
LEFT JOIN scene_triggers st ON st.scene_id = s.id
ORDER BY s.name;

-- List recent scene runs
SELECT 
    s.name,
    sr.started_at,
    sr.finished_at,
    sr.status,
    sr.logs_json
FROM scene_runs sr
JOIN scenes s ON s.id = sr.scene_id
ORDER BY sr.started_at DESC
LIMIT 20;
```

### Manual Trigger Check

You can manually trigger a check using:

```dart
final scheduler = SceneTriggerScheduler();
await scheduler.checkNow();
```

---

## Common Issues and Solutions

### Issue: Scene Not Executing

**Possible Causes:**
1. Scene is disabled (`is_enabled = false`)
2. Trigger is disabled
3. Scheduler is not running
4. Time doesn't match (check hour/minute in config_json)
5. App was terminated (foreground scheduler only works when app is running)

**Solution:**
- Check console logs for scheduler status
- Verify scene and trigger are enabled
- Check trigger configuration in database
- Ensure app is running (foreground or background)

---

### Issue: Duplicate Executions

**Possible Causes:**
1. Multiple scheduler instances running
2. Duplicate prevention logic not working

**Solution:**
- Check for multiple "Starting..." messages in logs
- Verify singleton pattern is working
- Check `_lastExecutionTimes` map

---

### Issue: Background Execution Not Working

**Possible Causes:**
1. App was terminated (foreground scheduler stops)
2. Background executor not fully implemented
3. Permissions not granted

**Solution:**
- Current implementation relies on foreground scheduler
- Full background execution requires authentication setup
- Check platform permissions are configured

---

## Performance Benchmarks

### Expected Performance

- **Scheduler Check Time:** < 100ms per check
- **Scene Execution Time:** 500ms - 2s (depends on device count)
- **Memory Usage:** < 10MB for scheduler
- **Battery Impact:** Minimal (timer runs every minute)

### Monitoring

```dart
// Add timing logs
final stopwatch = Stopwatch()..start();
await _checkAndExecuteTriggers();
stopwatch.stop();
debugPrint('⏰ Check took ${stopwatch.elapsedMilliseconds}ms');
```

---

## Automated Testing (Future)

### Unit Tests

```dart
test('shouldTriggerFire returns true for matching time', () {
  final trigger = SceneTrigger(
    id: 'test-id',
    sceneId: 'scene-id',
    kind: TriggerKind.schedule,
    configJson: {'hour': 14, 'minute': 30, 'days': [1,2,3,4,5,6,7]},
    isEnabled: true,
    createdAt: DateTime.now(),
  );
  
  final result = _shouldTriggerFire(trigger, 14, 30, 1);
  expect(result, true);
});
```

### Integration Tests

```dart
testWidgets('Scene executes at scheduled time', (tester) async {
  // Create scene with trigger
  // Wait for trigger time
  // Verify scene executed
});
```

---

## Conclusion

This testing guide covers:
- ✅ Basic functionality testing
- ✅ Edge case testing
- ✅ Performance testing
- ✅ Debugging techniques
- ✅ Common issues and solutions

Follow these tests to ensure the scene trigger system works correctly in all scenarios.

