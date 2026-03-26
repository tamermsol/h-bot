import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Persistent cache for device state (shutter positions, power states, etc.)
/// This cache provides instant feedback on app startup while MQTT reconnects
/// 
/// CRITICAL: This is a DISPLAY-ONLY cache for instant UI feedback
/// - Real-time MQTT data is ALWAYS the source of truth
/// - Cache is updated whenever MQTT data arrives
/// - Cache is read ONLY on app startup before MQTT connects
/// - Database should NOT store real-time state (only metadata)
class DeviceStateCache {
  static const String _shutterPositionPrefix = 'shutter_position_';
  static const String _powerStatePrefix = 'power_state_';
  static const String _lastUpdatePrefix = 'last_update_';

  /// Singleton instance
  static final DeviceStateCache _instance = DeviceStateCache._internal();
  factory DeviceStateCache() => _instance;
  DeviceStateCache._internal();

  SharedPreferences? _prefs;

  /// Initialize the cache (call this on app startup)
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('📦 DeviceStateCache initialized');
  }

  /// Get SharedPreferences instance (lazy initialization)
  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ==================== SHUTTER POSITION CACHE ====================

  /// Save shutter position to cache
  /// deviceId: Device UUID
  /// shutterIndex: 1-4 (Shutter1, Shutter2, etc.)
  /// position: 0-100
  Future<void> saveShutterPosition(
    String deviceId,
    int shutterIndex,
    int position,
  ) async {
    try {
      final prefs = await _preferences;
      final key = '$_shutterPositionPrefix${deviceId}_$shutterIndex';
      final sanitizedPosition = position.clamp(0, 100);
      
      await prefs.setInt(key, sanitizedPosition);
      await _saveLastUpdate(deviceId, shutterIndex);
      
      debugPrint(
        '💾 Cached shutter position: $deviceId Shutter$shutterIndex = $sanitizedPosition%',
      );
    } catch (e) {
      debugPrint('⚠️ Error saving shutter position to cache: $e');
    }
  }

  /// Get cached shutter position
  /// Returns null if no cached value exists
  Future<int?> getShutterPosition(String deviceId, int shutterIndex) async {
    try {
      final prefs = await _preferences;
      final key = '$_shutterPositionPrefix${deviceId}_$shutterIndex';
      final position = prefs.getInt(key);
      
      if (position != null) {
        debugPrint(
          '📦 Retrieved cached shutter position: $deviceId Shutter$shutterIndex = $position%',
        );
      }
      
      return position;
    } catch (e) {
      debugPrint('⚠️ Error reading shutter position from cache: $e');
      return null;
    }
  }

  /// Get all cached shutter positions for a device (Shutter1-4)
  /// Returns a map: {1: 50, 2: 75, ...} for shutters that have cached values
  Future<Map<int, int>> getAllShutterPositions(String deviceId) async {
    final Map<int, int> positions = {};
    
    for (int i = 1; i <= 4; i++) {
      final position = await getShutterPosition(deviceId, i);
      if (position != null) {
        positions[i] = position;
      }
    }
    
    return positions;
  }

  /// Clear cached shutter position
  Future<void> clearShutterPosition(String deviceId, int shutterIndex) async {
    try {
      final prefs = await _preferences;
      final key = '$_shutterPositionPrefix${deviceId}_$shutterIndex';
      await prefs.remove(key);
      await _clearLastUpdate(deviceId, shutterIndex);
      
      debugPrint(
        '🗑️ Cleared cached shutter position: $deviceId Shutter$shutterIndex',
      );
    } catch (e) {
      debugPrint('⚠️ Error clearing shutter position from cache: $e');
    }
  }

  // ==================== POWER STATE CACHE ====================

  /// Save power state to cache (for relay/dimmer devices)
  /// deviceId: Device UUID
  /// channel: 1-8 (POWER1, POWER2, etc.)
  /// state: 'ON' or 'OFF'
  Future<void> savePowerState(
    String deviceId,
    int channel,
    String state,
  ) async {
    try {
      final prefs = await _preferences;
      final key = '$_powerStatePrefix${deviceId}_$channel';
      
      await prefs.setString(key, state);
      await _saveLastUpdate(deviceId, channel);
      
      debugPrint(
        '💾 Cached power state: $deviceId POWER$channel = $state',
      );
    } catch (e) {
      debugPrint('⚠️ Error saving power state to cache: $e');
    }
  }

  /// Get cached power state
  /// Returns null if no cached value exists
  Future<String?> getPowerState(String deviceId, int channel) async {
    try {
      final prefs = await _preferences;
      final key = '$_powerStatePrefix${deviceId}_$channel';
      final state = prefs.getString(key);
      
      if (state != null) {
        debugPrint(
          '📦 Retrieved cached power state: $deviceId POWER$channel = $state',
        );
      }
      
      return state;
    } catch (e) {
      debugPrint('⚠️ Error reading power state from cache: $e');
      return null;
    }
  }

  /// Get all cached power states for a device (POWER1-8)
  /// Returns a map: {1: 'ON', 2: 'OFF', ...} for channels that have cached values
  Future<Map<int, String>> getAllPowerStates(String deviceId) async {
    final Map<int, String> states = {};
    
    for (int i = 1; i <= 8; i++) {
      final state = await getPowerState(deviceId, i);
      if (state != null) {
        states[i] = state;
      }
    }
    
    return states;
  }

  /// Clear cached power state
  Future<void> clearPowerState(String deviceId, int channel) async {
    try {
      final prefs = await _preferences;
      final key = '$_powerStatePrefix${deviceId}_$channel';
      await prefs.remove(key);
      await _clearLastUpdate(deviceId, channel);
      
      debugPrint(
        '🗑️ Cleared cached power state: $deviceId POWER$channel',
      );
    } catch (e) {
      debugPrint('⚠️ Error clearing power state from cache: $e');
    }
  }

  // ==================== DEVICE-LEVEL OPERATIONS ====================

  /// Clear all cached state for a device
  Future<void> clearDeviceCache(String deviceId) async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys();
      
      // Remove all keys related to this device
      for (final key in keys) {
        if (key.contains(deviceId)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('🗑️ Cleared all cached state for device: $deviceId');
    } catch (e) {
      debugPrint('⚠️ Error clearing device cache: $e');
    }
  }

  /// Clear all cached state (useful for logout or reset)
  Future<void> clearAllCache() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys();
      
      // Remove all device state keys
      for (final key in keys) {
        if (key.startsWith(_shutterPositionPrefix) ||
            key.startsWith(_powerStatePrefix) ||
            key.startsWith(_lastUpdatePrefix)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('🗑️ Cleared all device state cache');
    } catch (e) {
      debugPrint('⚠️ Error clearing all cache: $e');
    }
  }

  // ==================== METADATA ====================

  /// Save last update timestamp
  Future<void> _saveLastUpdate(String deviceId, int index) async {
    try {
      final prefs = await _preferences;
      final key = '$_lastUpdatePrefix${deviceId}_$index';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt(key, timestamp);
    } catch (e) {
      debugPrint('⚠️ Error saving last update timestamp: $e');
    }
  }

  /// Clear last update timestamp
  Future<void> _clearLastUpdate(String deviceId, int index) async {
    try {
      final prefs = await _preferences;
      final key = '$_lastUpdatePrefix${deviceId}_$index';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('⚠️ Error clearing last update timestamp: $e');
    }
  }

  /// Get last update timestamp
  Future<DateTime?> getLastUpdate(String deviceId, int index) async {
    try {
      final prefs = await _preferences;
      final key = '$_lastUpdatePrefix${deviceId}_$index';
      final timestamp = prefs.getInt(key);
      
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      
      return null;
    } catch (e) {
      debugPrint('⚠️ Error reading last update timestamp: $e');
      return null;
    }
  }

  /// Check if cached data is stale (older than specified duration)
  Future<bool> isCacheStale(
    String deviceId,
    int index, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final lastUpdate = await getLastUpdate(deviceId, index);
    
    if (lastUpdate == null) {
      return true; // No cache = stale
    }
    
    final age = DateTime.now().difference(lastUpdate);
    return age > maxAge;
  }
}

