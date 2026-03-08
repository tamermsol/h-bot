# 📋 Runtime MQTT Telemetry - TODO

## ⏳ Status: NOT YET IMPLEMENTED

This document outlines the remaining work needed to implement **Runtime MQTT Telemetry** handling for shutter devices.

---

## 🎯 Requirement (from user)

> **C) Runtime MQTT (telemetry keeps DB truthful)**
> 
> Subscribe to `stat/<topic>/STATUS8` and `stat/<topic>/RESULT`.
> 
> If a payload contains `Shutter1` (object or number), parse it and upsert to `shutter_states`.
> 
> On any valid shutter payload, set `devices.online=true` and refresh `last_seen_at`.
> 
> If telemetry shows shutter evidence and the DB still says relay, rewrite it to `shutter` + `channel_count=1`.

---

## 📝 Implementation Plan

### **1. MQTT Subscription**

**File to modify**: `lib/services/enhanced_mqtt_service.dart` or `lib/services/tasmota_mqtt_service.dart`

**Changes needed**:
- Subscribe to `stat/+/STATUS8` topic (wildcard for all devices)
- Subscribe to `stat/+/RESULT` topic (wildcard for all devices)
- Parse incoming messages for `Shutter1` field

**Example code**:
```dart
// In MQTT service initialization
void _subscribeToShutterTelemetry() {
  // Subscribe to STATUS8 for all devices
  _client.subscribe('stat/+/STATUS8', MqttQos.atLeastOnce);
  
  // Subscribe to RESULT for all devices
  _client.subscribe('stat/+/RESULT', MqttQos.atLeastOnce);
  
  debugPrint('📡 Subscribed to shutter telemetry topics');
}

// In message handler
void _handleShutterTelemetry(String topic, String payload) {
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    
    // Extract topic base from topic (e.g., "stat/Hbot_XXXXXX/STATUS8" -> "Hbot_XXXXXX")
    final topicParts = topic.split('/');
    if (topicParts.length < 2) return;
    final topicBase = topicParts[1];
    
    // Check for Shutter1 field
    if (_hasShutterData(data)) {
      _processShutterUpdate(topicBase, data);
    }
  } catch (e) {
    debugPrint('❌ Failed to parse shutter telemetry: $e');
  }
}

bool _hasShutterData(Map<String, dynamic> data) {
  // Check for Shutter1 in various locations
  if (data.containsKey('Shutter1')) return true;
  
  final statusSNS = data['StatusSNS'] as Map<String, dynamic>?;
  if (statusSNS != null && statusSNS.containsKey('Shutter1')) return true;
  
  return false;
}
```

---

### **2. Parse Shutter Data**

**Handle both object and numeric forms**:

```dart
Map<String, dynamic> _parseShutterData(Map<String, dynamic> data) {
  dynamic shutter1;
  
  // Try StatusSNS.Shutter1 first
  final statusSNS = data['StatusSNS'] as Map<String, dynamic>?;
  if (statusSNS != null && statusSNS.containsKey('Shutter1')) {
    shutter1 = statusSNS['Shutter1'];
  } else if (data.containsKey('Shutter1')) {
    shutter1 = data['Shutter1'];
  }
  
  if (shutter1 == null) return {};
  
  // Handle object form: {"Position": 50, "Direction": 1, "Target": 100}
  if (shutter1 is Map<String, dynamic>) {
    return {
      'position': shutter1['Position'] as int?,
      'direction': shutter1['Direction'] as int?,
      'target': shutter1['Target'] as int?,
      'tilt': shutter1['Tilt'] as int?,
    };
  }
  
  // Handle numeric form: 50 (just position)
  if (shutter1 is int) {
    return {
      'position': shutter1,
      'direction': null,
      'target': null,
      'tilt': null,
    };
  }
  
  return {};
}
```

---

### **3. Update Database**

**Call the helper functions created earlier**:

```dart
Future<void> _processShutterUpdate(String topicBase, Map<String, dynamic> data) async {
  try {
    // Parse shutter data
    final shutterData = _parseShutterData(data);
    if (shutterData.isEmpty) return;
    
    // Find device by topic_base
    final deviceResponse = await Supabase.instance.client
        .from('devices')
        .select('id, device_type')
        .eq('topic_base', topicBase)
        .maybeSingle();
    
    if (deviceResponse == null) {
      debugPrint('⚠️ Device not found for topic: $topicBase');
      return;
    }
    
    final deviceId = deviceResponse['id'] as String;
    final deviceType = deviceResponse['device_type'] as String;
    
    // If device is still marked as relay, re-classify it
    if (deviceType != 'shutter') {
      debugPrint('🔄 Re-classifying device as shutter: $topicBase');
      await Supabase.instance.client.rpc(
        'reclassify_as_shutter',
        params: {'p_topic_base': topicBase},
      );
    }
    
    // Upsert shutter state
    await Supabase.instance.client.rpc(
      'upsert_shutter_state',
      params: {
        'p_device_id': deviceId,
        'p_position': shutterData['position'],
        'p_direction': shutterData['direction'],
        'p_target': shutterData['target'],
        'p_tilt': shutterData['tilt'],
      },
    );
    
    // Mark device online
    await Supabase.instance.client.rpc(
      'mark_device_online',
      params: {'p_device_id': deviceId},
    );
    
    debugPrint('✅ Shutter state updated for $topicBase: ${shutterData['position']}%');
  } catch (e) {
    debugPrint('❌ Failed to process shutter update: $e');
  }
}
```

---

### **4. Integration Points**

**Where to add the code**:

1. **MQTT Service Initialization**:
   - Add `_subscribeToShutterTelemetry()` call in `connect()` method
   - File: `lib/services/enhanced_mqtt_service.dart`

2. **Message Handler**:
   - Add `_handleShutterTelemetry()` call in existing message handler
   - File: `lib/services/enhanced_mqtt_service.dart`
   - Look for where `_client.updates?.listen()` is called

3. **UI Updates**:
   - The existing `device_shutters` view subscription should automatically update the UI
   - No additional changes needed if using Supabase real-time subscriptions

---

## 🧪 Testing Plan

### **1. Subscribe Verification**
- [ ] Check MQTT broker logs for subscriptions to `stat/+/STATUS8` and `stat/+/RESULT`
- [ ] Use MQTT Explorer to verify subscriptions are active

### **2. Telemetry Parsing**
- [ ] Publish test message to `stat/Hbot_XXXXXX/STATUS8`:
  ```json
  {"StatusSNS": {"Shutter1": {"Position": 50, "Direction": 1, "Target": 100}}}
  ```
- [ ] Check debug logs for: `✅ Shutter state updated for Hbot_XXXXXX: 50%`

- [ ] Publish numeric form to `stat/Hbot_XXXXXX/RESULT`:
  ```json
  {"Shutter1": 75}
  ```
- [ ] Check debug logs for: `✅ Shutter state updated for Hbot_XXXXXX: 75%`

### **3. Database Updates**
- [ ] Query `shutter_states` table after telemetry:
  ```sql
  SELECT * FROM shutter_states WHERE device_id = '<device-id>';
  ```
- [ ] Verify `position`, `direction`, `target` match telemetry
- [ ] Verify `updated_at` is recent

- [ ] Query `devices` table:
  ```sql
  SELECT online, last_seen_at FROM devices WHERE id = '<device-id>';
  ```
- [ ] Verify `online = true`
- [ ] Verify `last_seen_at` is recent

### **4. Re-classification Test**
- [ ] Manually set device to relay:
  ```sql
  UPDATE devices SET device_type = 'relay' WHERE id = '<device-id>';
  ```
- [ ] Trigger telemetry (move shutter with wall switch)
- [ ] Verify device is re-classified:
  ```sql
  SELECT device_type, channel_count FROM devices WHERE id = '<device-id>';
  ```
- [ ] Expected: `device_type='shutter'`, `channel_count=1`

### **5. UI Update Test**
- [ ] Open device detail screen
- [ ] Move shutter with wall switch
- [ ] Verify slider position updates within ~1 second
- [ ] Verify no page refresh needed

---

## 📁 Files to Modify

1. **`lib/services/enhanced_mqtt_service.dart`**
   - Add shutter telemetry subscription
   - Add message handler for STATUS8 and RESULT
   - Add parsing logic for Shutter1 data
   - Add database update calls

2. **`lib/services/tasmota_mqtt_service.dart`** (if separate)
   - Same changes as above

---

## ⚠️ Important Notes

1. **Idempotency**: All database functions (`upsert_shutter_state`, `mark_device_online`, `reclassify_as_shutter`) are idempotent and safe to call multiple times.

2. **Error Handling**: Telemetry processing should never crash the app. Wrap all database calls in try-catch blocks.

3. **Performance**: Consider debouncing rapid telemetry updates (e.g., only update database every 500ms max).

4. **Topic Matching**: Make sure to correctly extract `topic_base` from MQTT topic. The format is `stat/<topic_base>/STATUS8`.

5. **Null Safety**: Handle both object and numeric forms of `Shutter1`. Some Tasmota versions send just the position as a number.

---

## 🎯 Success Criteria

When complete, the following should work:

1. ✅ App subscribes to `stat/+/STATUS8` and `stat/+/RESULT` on MQTT connect
2. ✅ Incoming shutter telemetry is parsed correctly (both object and numeric forms)
3. ✅ Database is updated with latest position/direction/target
4. ✅ Device is marked online and `last_seen_at` is refreshed
5. ✅ Devices incorrectly marked as relay are re-classified to shutter
6. ✅ UI updates in real-time without page refresh
7. ✅ Wall switch movements update the app within ~1 second

---

## 📞 Next Steps

1. Implement the MQTT subscription and message handling
2. Test with real device telemetry
3. Verify database updates
4. Test UI real-time updates
5. Test re-classification logic

**This is the final piece needed for complete shutter support!**

