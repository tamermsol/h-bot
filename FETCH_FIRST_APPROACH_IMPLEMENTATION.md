# Fetch-First Approach Implementation for Light Devices

## 🎯 Overview

This document describes the implementation of a **"fetch-first"** approach for light devices (relay/dimmer) that eliminates flickering by waiting for real device state from physical Tasmota devices before displaying the UI.

## 🐛 Critical Bugs Fixed (v2)

### **Bug 1: Initial State Emission Before MQTT Response**
**Location**: Line 1140 in `enhanced_mqtt_service.dart`
**Problem**: The code was emitting initial state to UI immediately after device registration, BEFORE waiting for MQTT response.
**Fix**: Only emit initial state for shutter devices (cache-first). Skip emission for light devices (fetch-first).

### **Bug 2: State Updates Not Suppressed During Wait**
**Location**: Line 3198 in `_notifyDeviceStateChange()` method
**Problem**: The `waitingForInitialState` flag was set, but state updates were STILL being emitted to UI on every MQTT message (POWER, RESULT, STATUS, LWT).
**Fix**: Check `_devicesWaitingForInitialState` set before emitting state updates. Suppress all updates until initial state is complete.

### **Bug 3: No State Emission After Initial State Complete**
**Location**: Lines 2865-2886 and 2980-2998
**Problem**: After receiving initial state, the completer was completed but NO state update was emitted to UI, leaving the loading indicator forever.
**Fix**: Explicitly emit state update to UI immediately after completing initial state in both `_parseStateMessage()` and `_parseResultMessage()`.

### Previous Approach (Cache-First)
- Load cached power states from `SharedPreferences` on app startup
- Display cached state immediately
- Update when MQTT state arrives
- **Problem**: Multiple state updates caused flickering (cached → MQTT message 1 → MQTT message 2 → real state)

### New Approach (Fetch-First)
- **DO NOT** load cached states for light devices
- Mark device as "waiting for initial state"
- Show **loading indicator** in UI
- Send MQTT `STATE` command to query physical device
- Wait for response from Tasmota device
- Display state **only once** when real data arrives
- **Result**: No flickering, always shows actual device state

---

## 🔧 Implementation Details

### 1. Enhanced MQTT Service Changes

**File**: `lib/services/enhanced_mqtt_service.dart`

#### A. Added Tracking Mechanism (Lines 119-122)

```dart
// Track devices waiting for initial state from physical Tasmota device
// This enables "fetch-first" approach where UI waits for real device state
final Set<String> _devicesWaitingForInitialState = {};
final Map<String, Completer<void>> _initialStateCompleters = {};
```

#### B. Modified Device Registration (Lines 1051-1068)

**REMOVED**: Cache loading for light devices
```dart
// OLD CODE (REMOVED):
final cachedPowerStates = await _stateCache.getAllPowerStates(device.id);
for (int i = 1; i <= device.effectiveChannels; i++) {
  final cachedState = cachedPowerStates[i] ?? 'OFF';
  _deviceStates[device.id]!['POWER$i'] = cachedState;
}
```

**NEW CODE**: Mark as waiting for initial state
```dart
// FETCH-FIRST APPROACH for relay/dimmer devices
// DO NOT load cached states - wait for real device state from MQTT
if (device.effectiveChannels > 0 && device.deviceType != DeviceType.shutter) {
  // Mark device as waiting for initial state from physical Tasmota device
  _devicesWaitingForInitialState.add(device.id);
  
  // Create a completer that will be completed when we receive STATE response
  _initialStateCompleters[device.id] = Completer<void>();
  
  // Set a flag in device state to indicate we're waiting for initial data
  _deviceStates[device.id]!['waitingForInitialState'] = true;
  
  _addDebugMessage(
    '⏳ ${device.name} marked as waiting for initial state from physical device',
  );
}
```

**Note**: Shutter devices still use cache-first approach to prevent 0% flash.

#### C. STATE Command Sent (Lines 1128-1132)

The existing code already sends a `STATE` command to query all power states:

```dart
// Request initial state - use STATE command for faster bulk retrieval
final stateTopic = 'cmnd/${device.tasmotaTopicBase}/STATE';
await _publishMessage(stateTopic, '');
_addDebugMessage('Requested initial STATE for all channels');
```

**Tasmota STATE Command**:
- **Topic**: `cmnd/<topic_base>/STATE`
- **Payload**: Empty string
- **Response Topic**: `stat/<topic_base>/RESULT` or `tele/<topic_base>/STATE`
- **Response Payload**: JSON with all POWER states, e.g.:
  ```json
  {
    "Time": "2024-01-15T10:30:00",
    "Uptime": "0T12:34:56",
    "POWER1": "ON",
    "POWER2": "OFF",
    "POWER3": "ON",
    "POWER4": "OFF",
    "Wifi": {"RSSI": -65}
  }
  ```

#### D. Complete Initial State on Response (Lines 2816-2832)

When `_parseStateMessage()` receives the STATE response:

```dart
// FETCH-FIRST: Complete initial state loading if this device was waiting
if (_devicesWaitingForInitialState.contains(deviceId)) {
  _devicesWaitingForInitialState.remove(deviceId);
  _deviceStates[deviceId]!.remove('waitingForInitialState');
  
  // Complete the completer to signal that initial state is ready
  final completer = _initialStateCompleters.remove(deviceId);
  if (completer != null && !completer.isCompleted) {
    completer.complete();
    _addDebugMessage(
      '✅ ${device.name} initial state received from physical device',
    );
  }
}
```

#### E. Also Handle RESULT Messages (Lines 2911-2941)

RESULT messages can also contain POWER states (from command responses):

```dart
// FETCH-FIRST: Complete initial state loading if this device was waiting
if (_devicesWaitingForInitialState.contains(deviceId)) {
  // Check if we have at least one POWER state in the result
  bool hasPowerState = false;
  for (int i = 1; i <= device.effectiveChannels; i++) {
    if (resultData.containsKey('POWER$i')) {
      hasPowerState = true;
      break;
    }
  }
  
  if (hasPowerState) {
    _devicesWaitingForInitialState.remove(deviceId);
    _deviceStates[deviceId]!.remove('waitingForInitialState');
    
    final completer = _initialStateCompleters.remove(deviceId);
    if (completer != null && !completer.isCompleted) {
      completer.complete();
      _addDebugMessage(
        '✅ ${device.name} initial state received from physical device (via RESULT)',
      );
    }
  }
}
```

#### F. Public API Methods (Lines 281-314)

```dart
/// Check if a device is waiting for initial state from physical Tasmota device
bool isWaitingForInitialState(String deviceId) {
  return _devicesWaitingForInitialState.contains(deviceId);
}

/// Wait for initial state to be received from physical Tasmota device
/// Returns true if state was received, false if timeout occurred
/// Timeout defaults to 5 seconds
Future<bool> waitForInitialState(
  String deviceId, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final completer = _initialStateCompleters[deviceId];
  if (completer == null || completer.isCompleted) {
    return true; // Already received or not waiting
  }

  try {
    await completer.future.timeout(timeout);
    return true;
  } on TimeoutException {
    _addDebugMessage('⚠️ Timeout waiting for initial state for device: $deviceId');
    
    // Clean up on timeout
    _devicesWaitingForInitialState.remove(deviceId);
    _initialStateCompleters.remove(deviceId);
    _deviceStates[deviceId]?.remove('waitingForInitialState');
    
    return false;
  }
}
```

---

### 2. UI Changes

**File**: `lib/screens/home_dashboard_screen.dart`

#### A. Extract Loading Flag (Lines 1143-1147)

```dart
// FETCH-FIRST: Check if device is waiting for initial state from physical device
bool waitingForInitialState = false;
if (merged != null && merged.containsKey('waitingForInitialState')) {
  waitingForInitialState = merged['waitingForInitialState'] == true;
}
```

#### B. List View - Show Loading Indicator (Lines 1319-1343)

```dart
// FETCH-FIRST: Show loading indicator while waiting for initial state
if (waitingForInitialState)
  const SizedBox(
    width: 24,
    height: 24,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      valueColor: AlwaysStoppedAnimation<Color>(
        AppTheme.primaryColor,
      ),
    ),
  )
else
  Switch(
    value: deviceState,
    onChanged: isControllable && _mqttConnected && isOnline
        ? (value) => _toggleDevice(device, value)
        : null,
    activeThumbColor: AppTheme.primaryColor,
  ),
```

#### C. Grid View - Show Loading Indicator (Lines 1504-1529)

```dart
Center(
  // FETCH-FIRST: Show loading indicator while waiting for initial state
  child: waitingForInitialState
      ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryColor,
            ),
          ),
        )
      : Transform.scale(
          scale: 0.85,
          child: Switch(
            value: deviceState,
            onChanged: isControllable && _mqttConnected && isOnline
                ? (value) => _toggleDevice(device, value)
                : null,
            activeThumbColor: AppTheme.primaryColor,
          ),
        ),
),
```

---

## 📊 State Flow Diagram

```
App Startup
    ↓
Device Registration
    ↓
Mark as "waitingForInitialState" = true
    ↓
Send MQTT: cmnd/<topic>/STATE
    ↓
UI Shows: CircularProgressIndicator
    ↓
Wait for Response...
    ↓
Receive: stat/<topic>/RESULT or tele/<topic>/STATE
    ↓
Parse POWER1, POWER2, etc.
    ↓
Complete Completer
    ↓
Remove "waitingForInitialState" flag
    ↓
UI Updates: Show Switch with Real State
    ↓
✅ No Flickering!
```

---

## 🎯 Key Benefits

1. **No Flickering**: UI updates only once with real device state
2. **Always Accurate**: State comes directly from physical Tasmota device
3. **Clear Feedback**: Loading indicator shows user that state is being fetched
4. **Timeout Protection**: 5-second timeout prevents infinite loading
5. **Shutter Compatibility**: Shutters still use cache-first to prevent 0% flash

---

## 🧪 Testing Instructions

### Test 1: Light Device ON → Close App → Reopen
1. Turn on a light device (all channels or specific channels)
2. Completely close the app (swipe away from recent apps)
3. Reopen the app
4. **Expected**:
   - Light device shows **loading indicator** (spinning circle)
   - After ~1-2 seconds, loading indicator disappears
   - Light shows **ON** state (correct state from physical device)
   - **NO flickering** between ON/OFF states

### Test 2: Light Device OFF → Close App → Reopen
1. Turn off a light device
2. Completely close the app
3. Reopen the app
4. **Expected**:
   - Light device shows **loading indicator**
   - After ~1-2 seconds, loading indicator disappears
   - Light shows **OFF** state
   - **NO flickering**

### Test 3: Multi-Channel Device
1. Turn on channels 1 and 3 of a 4-channel device
2. Close and reopen app
3. **Expected**:
   - Loading indicator appears
   - All channels show correct state (1=ON, 2=OFF, 3=ON, 4=OFF)
   - **NO flickering**

### Test 4: Timeout Scenario (Device Offline)
1. Turn off a physical Tasmota device (unplug it)
2. Close and reopen app
3. **Expected**:
   - Loading indicator appears
   - After 5 seconds, loading indicator disappears
   - Device shows as offline/unavailable
   - No infinite loading

---

## 📝 Summary

The fetch-first approach successfully eliminates flickering by:
- **Removing** cached state loading for light devices
- **Waiting** for real device state from MQTT
- **Showing** loading indicator during wait
- **Updating** UI only once when real data arrives

This ensures the displayed state always reflects the actual physical device state, with no intermediate flickering.

