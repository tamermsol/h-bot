# Manual Test: Real-time State Updates for Physical Switch Operations

## Test Objective
Verify that physical switch operations on devices are immediately reflected in the app UI without requiring an app restart.

## Prerequisites
1. Flutter app with the updated MQTT state synchronization system
2. At least 2 Tasmota devices configured and connected to the same home
3. Devices should be properly registered in the app
4. MQTT broker accessible and devices connected

## Test Procedure

### Test 1: Single Device Physical Switch
1. **Setup**:
   - Open the app and navigate to home dashboard
   - Ensure at least one device is visible and shows current state
   - Note the current state of device channels

2. **Action**:
   - Physically press a button/switch on the device
   - Observe the app UI immediately after the press

3. **Expected Result**:
   - The device state in the app should update within 1-2 seconds
   - The UI should reflect the new channel state without manual refresh
   - No app restart should be required

4. **Verification**:
   - Check that the switch/button in the app matches the physical device state
   - Verify the state persists if you navigate away and back to the screen

### Test 2: Multi-Device Physical Switch Operations
1. **Setup**:
   - Ensure multiple devices are visible in the home dashboard
   - Note the current states of all devices

2. **Action**:
   - Rapidly press physical switches on different devices
   - Alternate between devices every 2-3 seconds

3. **Expected Result**:
   - Each device state should update independently in real-time
   - No device state should interfere with others
   - All updates should appear without app restart

4. **Verification**:
   - Confirm each device shows the correct state after physical operation
   - Verify states persist across screen navigation

### Test 3: Device Control Screen Real-time Updates
1. **Setup**:
   - Open a specific device control screen
   - Note the current channel states displayed

2. **Action**:
   - While viewing the device control screen, physically operate the device switches
   - Test both single and multi-channel devices if available

3. **Expected Result**:
   - The device control screen should update in real-time
   - Channel states should reflect physical switch positions immediately
   - No manual refresh or screen reload required

4. **Verification**:
   - Compare physical device LED states with app display
   - Ensure all channels update correctly

### Test 4: App Control vs Physical Switch Conflict Resolution
1. **Setup**:
   - Have the device control screen open
   - Ensure device is responsive to app commands

2. **Action**:
   - Send a command from the app (e.g., turn channel ON)
   - Immediately after, physically press the same switch to turn it OFF
   - Observe the conflict resolution

3. **Expected Result**:
   - The app should show optimistic update first (ON)
   - Then quickly update to reflect physical switch state (OFF)
   - Final state should match physical device state

4. **Verification**:
   - Physical device state should always take precedence
   - No stuck or inconsistent states should occur

### Test 5: Network Interruption Recovery
1. **Setup**:
   - Ensure devices are working normally with real-time updates
   - Have network monitoring capability

2. **Action**:
   - Temporarily disconnect WiFi/internet for 30 seconds
   - During disconnection, operate physical switches
   - Reconnect network

3. **Expected Result**:
   - After reconnection, app should sync with actual device states
   - Any state changes during disconnection should be reflected
   - Real-time updates should resume normally

4. **Verification**:
   - All device states should be accurate after reconnection
   - Subsequent physical switch operations should update in real-time

## Debug Information to Collect

### Console Logs to Monitor
Look for these log messages during testing:

```
📡 Real-time state change detected for device [deviceId]: [insert/update]
✅ Emitted real-time state update for device [deviceId] (type: [changeType])
📱 Combined state update for [deviceName]: [source] - [state]
📱 Combined device state updated from [source]: [state]
✅ Successfully persisted batch of [count] device states to database
```

### Performance Metrics
- Time from physical switch press to UI update (should be < 2 seconds)
- Database persistence latency (should be < 500ms)
- Memory usage during extended testing
- No memory leaks from stream subscriptions

## Success Criteria

### ✅ Pass Conditions
- [ ] Physical switch operations update UI within 2 seconds
- [ ] Multi-device operations work independently
- [ ] Device control screen updates in real-time
- [ ] Conflict resolution favors physical device state
- [ ] Network interruption recovery works correctly
- [ ] No app restart required for any state updates
- [ ] No memory leaks or performance degradation

### ❌ Fail Conditions
- Physical switch operations require app restart to be visible
- UI shows incorrect or stale device states
- Multi-device operations interfere with each other
- App crashes or becomes unresponsive
- Memory usage continuously increases during testing
- Network recovery fails to sync states

## Troubleshooting

### If Real-time Updates Don't Work
1. Check MQTT broker connectivity
2. Verify device topic configuration
3. Ensure Supabase real-time subscriptions are active
4. Check for JavaScript errors in debug console
5. Verify database permissions for real-time updates

### If Performance is Poor
1. Monitor database batch operations
2. Check for excessive stream subscriptions
3. Verify polling intervals are appropriate
4. Look for memory leaks in stream handling

### If States are Inconsistent
1. Check conflict resolution logic
2. Verify timestamp handling
3. Ensure database persistence is working
4. Check for race conditions in state updates

## Expected Test Duration
- Complete test suite: 15-20 minutes
- Individual test cases: 2-3 minutes each
- Network interruption test: 5 minutes

## Test Environment
- Device: [Record device model and OS]
- App Version: [Record app version]
- Network: [Record network conditions]
- MQTT Broker: [Record broker details]
- Number of Devices: [Record device count]
