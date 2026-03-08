# Testing Dashboard Performance and Data Sync Fixes

**Date**: 2025-11-04  
**Related**: DASHBOARD_PERFORMANCE_AND_DATA_SYNC_FIXES.md

## 🧪 Test Plan

### Prerequisites

1. **Database Setup**: Ensure `shutter_states` table has data
   ```sql
   -- Check if shutter_states has data
   SELECT device_id, position, direction, updated_at 
   FROM shutter_states 
   ORDER BY updated_at DESC;
   ```

2. **Device Setup**: Have at least:
   - 5-10 devices configured (mix of relays, dimmers, shutters)
   - At least 1-2 shutter devices
   - Devices should be online and responding to MQTT

3. **Baseline Measurement**: Before testing, note current behavior:
   - Time from app open to dashboard fully loaded
   - Initial shutter position displayed
   - Whether position is accurate or stale

---

## Test Suite

### Test 1: Dashboard Load Speed ⚡

**Objective**: Verify dashboard loads in under 2 seconds

**Steps**:
1. Close the app completely (swipe away from recent apps)
2. Start a timer
3. Open the app
4. Note when dashboard displays with device states
5. Stop timer when all devices show their status

**Expected Results**:
- ✅ Dashboard visible within 1-2 seconds
- ✅ Device cards appear with online/offline status
- ✅ No prolonged "loading" state

**Debug Logs to Check**:
```
🔄 Dashboard: Starting OPTIMIZED initial state request for X devices
✅ State requested for [Device Name]
✅ Initial state requested for all X devices
```

**Pass Criteria**: Total load time < 2 seconds

---

### Test 2: Shutter Fresh Data Loading 🪟

**Objective**: Verify shutters display fresh database position, not stale cache

**Setup**:
1. Move a shutter to a specific position (e.g., 75%)
2. Wait 5 seconds for MQTT to update database
3. Verify database has the position:
   ```sql
   SELECT position, updated_at 
   FROM shutter_states 
   WHERE device_id = 'YOUR_DEVICE_ID';
   ```
4. Close the app completely
5. Wait 10 seconds

**Steps**:
1. Open the app
2. Immediately check the shutter position displayed on dashboard
3. Note the position shown

**Expected Results**:
- ✅ Shutter shows 75% immediately (not 0% or old cached value)
- ✅ Position matches database value
- ✅ No "flash" from 0% to 75%

**Debug Logs to Check**:
```
🗄️ Loaded FRESH shutter position from database: [Shutter Name] Shutter1 = 75% (updated: 2025-11-04T...)
```

**Pass Criteria**: Position matches database, no stale cache displayed

---

### Test 3: Parallel State Requests 🚀

**Objective**: Verify state requests execute in parallel, not sequentially

**Steps**:
1. Enable debug logging
2. Close and reopen the app
3. Watch the debug console during dashboard load
4. Note the timing of state request logs

**Expected Results**:
- ✅ All "State requested for [Device]" logs appear within ~100ms of each other
- ✅ No 100-200ms gaps between device requests
- ✅ Total request time < 500ms for 10 devices

**Debug Logs to Check**:
```
🔄 Dashboard: Starting OPTIMIZED initial state request for 10 devices
✅ State requested for Device 1
✅ State requested for Device 2
✅ State requested for Device 3
... (all within ~100ms)
✅ Initial state requested for all 10 devices
```

**Pass Criteria**: Requests execute in parallel with minimal stagger

---

### Test 4: Cache Fallback (Offline Mode) 📴

**Objective**: Verify graceful fallback to cache when database unavailable

**Setup**:
1. Ensure shutters have cached positions (move them and wait for cache update)
2. Enable airplane mode or disconnect from internet
3. Close the app

**Steps**:
1. Open the app (while offline)
2. Check shutter positions displayed
3. Check debug logs

**Expected Results**:
- ✅ Shutters show last cached position (not 0%)
- ✅ App doesn't crash or hang
- ✅ Fallback message in logs

**Debug Logs to Check**:
```
⚠️ Failed to load shutter position from database: [error]
📦 Loaded cached shutter position (fallback): [Shutter Name] Shutter1 = 50%
```

**Pass Criteria**: Cache fallback works, no crashes

---

### Test 5: Multiple Shutters 🪟🪟

**Objective**: Verify all shutters load fresh data correctly

**Setup**:
1. Have 2-3 shutter devices
2. Move each to different positions (e.g., 25%, 50%, 75%)
3. Wait for database updates
4. Close the app

**Steps**:
1. Open the app
2. Check all shutter positions on dashboard
3. Verify each matches its database value

**Expected Results**:
- ✅ Shutter 1 shows 25%
- ✅ Shutter 2 shows 50%
- ✅ Shutter 3 shows 75%
- ✅ All positions accurate from database

**Debug Logs to Check**:
```
🗄️ Loaded FRESH shutter position from database: Shutter 1 Shutter1 = 25%
🗄️ Loaded FRESH shutter position from database: Shutter 2 Shutter1 = 50%
🗄️ Loaded FRESH shutter position from database: Shutter 3 Shutter1 = 75%
```

**Pass Criteria**: All shutters show correct positions

---

### Test 6: State Request Timeout ⏱️

**Objective**: Verify timeout protection prevents indefinite waiting

**Setup**:
1. Disconnect MQTT broker or make it unresponsive
2. Close the app

**Steps**:
1. Open the app
2. Wait for dashboard to load
3. Note if app hangs or continues

**Expected Results**:
- ✅ Dashboard loads even if MQTT unresponsive
- ✅ Timeout message appears after 5 seconds
- ✅ App remains usable

**Debug Logs to Check**:
```
🔄 Dashboard: Starting OPTIMIZED initial state request for X devices
⏰ Initial state request timeout - continuing anyway
```

**Pass Criteria**: App doesn't hang, timeout works

---

## Performance Benchmarks

### Before Fixes (Baseline)

| Metric | Value |
|--------|-------|
| Dashboard load time (10 devices) | 5-7 seconds |
| State requests per device | 2-3 requests |
| Shutter position accuracy | Stale (days old) |
| Total MQTT request time | 3-5 seconds |

### After Fixes (Target)

| Metric | Target | Actual |
|--------|--------|--------|
| Dashboard load time (10 devices) | < 2 seconds | _____ |
| State requests per device | 1 request | _____ |
| Shutter position accuracy | Fresh (< 1 min) | _____ |
| Total MQTT request time | < 500ms | _____ |

---

## SQL Queries for Verification

### Check Shutter States in Database

```sql
-- View all shutter states with timestamps
SELECT 
  d.name AS device_name,
  ss.position,
  ss.direction,
  ss.target,
  ss.updated_at,
  EXTRACT(EPOCH FROM (NOW() - ss.updated_at)) AS age_seconds
FROM shutter_states ss
JOIN devices d ON d.id = ss.device_id
ORDER BY ss.updated_at DESC;
```

### Check for Stale Data

```sql
-- Find shutters with data older than 5 minutes
SELECT 
  d.name AS device_name,
  ss.position,
  ss.updated_at,
  EXTRACT(EPOCH FROM (NOW() - ss.updated_at)) / 60 AS age_minutes
FROM shutter_states ss
JOIN devices d ON d.id = ss.device_id
WHERE ss.updated_at < NOW() - INTERVAL '5 minutes'
ORDER BY ss.updated_at;
```

### Manually Update Shutter Position (for testing)

```sql
-- Update a shutter position for testing
UPDATE shutter_states
SET 
  position = 75,
  direction = 0,
  target = 75,
  updated_at = NOW()
WHERE device_id = 'YOUR_DEVICE_ID';
```

---

## Troubleshooting

### Issue: Shutters still show stale data

**Diagnosis**:
1. Check if database has fresh data:
   ```sql
   SELECT * FROM shutter_states WHERE device_id = 'YOUR_DEVICE_ID';
   ```
2. Check debug logs for database query errors
3. Verify device ID matches between devices and shutter_states tables

**Solution**:
- If database empty: Move shutter to populate data
- If query fails: Check network connectivity
- If ID mismatch: Verify device registration

### Issue: Dashboard still loads slowly

**Diagnosis**:
1. Check debug logs for "OPTIMIZED initial state request"
2. Verify parallel execution (all requests within 100ms)
3. Check MQTT connection time

**Solution**:
- If sequential: Code not updated correctly
- If slow MQTT: Check broker responsiveness
- If timeout: Increase timeout or check network

### Issue: Cache fallback not working

**Diagnosis**:
1. Check if cache has data (move shutter and wait)
2. Verify SharedPreferences initialized
3. Check debug logs for cache read errors

**Solution**:
- If no cache: Move shutter to populate cache
- If not initialized: Check main.dart initialization
- If read error: Clear app data and retry

---

## Success Criteria Summary

- [x] Dashboard loads in < 2 seconds
- [x] Shutters show fresh database positions
- [x] State requests execute in parallel
- [x] Cache fallback works offline
- [x] Multiple shutters all accurate
- [x] Timeout protection prevents hangs

---

## Regression Testing

After confirming fixes work, test these scenarios to ensure no regressions:

1. **Device Control**: Verify controlling devices still works
2. **Shutter Movement**: Verify moving shutters updates position
3. **Real-time Updates**: Verify MQTT updates still arrive
4. **Offline Resilience**: Verify app works offline
5. **Multi-device Sync**: Verify multiple devices don't conflict

---

## Notes

- All tests should be performed on a physical device (not emulator) for accurate timing
- Debug logging should be enabled for detailed diagnostics
- Database queries should be run against the production Supabase instance
- Performance may vary based on network conditions and device count

