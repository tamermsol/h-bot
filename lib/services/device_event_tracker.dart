import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'activity_log_service.dart';
import 'notification_service.dart';

/// Tracks device state transitions and fires notifications + activity logs.
/// Call [trackState] with every MQTT state update for a device.
class DeviceEventTracker with WidgetsBindingObserver {
  static final DeviceEventTracker _instance = DeviceEventTracker._();
  factory DeviceEventTracker() => _instance;
  DeviceEventTracker._() {
    // Listen for app lifecycle to suppress false offline notifications
    WidgetsBinding.instance.addObserver(this);
  }

  final ActivityLogService _log = ActivityLogService();
  final NotificationService _notif = NotificationService();

  // Device name registry (id -> display name)
  final Map<String, String> _deviceNames = {};

  // Track previous online/power state per device
  final Map<String, bool> _lastOnline = {};
  final Map<String, Map<int, String>> _lastPower = {};

  // Debounce: don't spam for rapid reconnections
  final Map<String, DateTime> _lastNotifTime = {};
  static const _debounce = Duration(minutes: 2);

  // Suppress offline notifications when app is not in foreground
  // or just resumed (MQTT reconnecting)
  bool _isInForeground = true;
  DateTime _lastResumeTime = DateTime.now();
  static const _reconnectGrace = Duration(seconds: 60);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      _lastResumeTime = DateTime.now();
      // Clear all "offline" states — devices will report fresh via MQTT
      _lastOnline.clear();
      debugPrint('📱 DeviceEventTracker: app resumed, cleared offline states');
    } else if (state == AppLifecycleState.paused ||
               state == AppLifecycleState.inactive) {
      _isInForeground = false;
      debugPrint('📱 DeviceEventTracker: app backgrounded, suppressing offline notifs');
    }
  }

  /// Register a device name for better log/notification display.
  void registerDevice(String deviceId, String displayName) {
    _deviceNames[deviceId] = displayName;
  }

  /// Call this with each combined state update from MQTT.
  void trackState(String deviceId, String deviceName, Map<String, dynamic> state) {
    // Use registered display name if available
    deviceName = _deviceNames[deviceId] ?? deviceName;
    _trackOnlineOffline(deviceId, deviceName, state);
    _trackPowerChanges(deviceId, deviceName, state);
  }

  void _trackOnlineOffline(String deviceId, String deviceName, Map<String, dynamic> state) {
    final isOnline = _extractOnline(state);
    if (isOnline == null) return;

    final wasOnline = _lastOnline[deviceId];
    _lastOnline[deviceId] = isOnline;

    // Skip first observation (initialization)
    if (wasOnline == null) return;
    // No change
    if (wasOnline == isOnline) return;

    final now = DateTime.now();
    final lastNotif = _lastNotifTime[deviceId];
    final shouldNotify = lastNotif == null || now.difference(lastNotif) > _debounce;

    // Suppress offline notifications when:
    // 1. App is not in foreground (MQTT disconnects on background)
    // 2. App just resumed (MQTT is reconnecting, false offline blip)
    final inReconnectGrace = now.difference(_lastResumeTime) < _reconnectGrace;
    final suppressOffline = !_isInForeground || inReconnectGrace;

    if (isOnline) {
      _log.log(
        deviceId: deviceId,
        deviceName: deviceName,
        eventType: ActivityEventType.deviceOnline,
        description: 'Device came online',
      );
      if (shouldNotify) {
        _notif.notifyDeviceOnline(deviceName);
        _lastNotifTime[deviceId] = now;
      }
    } else {
      _log.log(
        deviceId: deviceId,
        deviceName: deviceName,
        eventType: ActivityEventType.deviceOffline,
        description: 'Device went offline',
      );
      if (shouldNotify && !suppressOffline) {
        _notif.notifyDeviceOffline(deviceName);
        _lastNotifTime[deviceId] = now;
      } else if (suppressOffline) {
        debugPrint('🔇 Suppressed offline notification for $deviceName (app backgrounded or reconnecting)');
      }
    }
  }

  void _trackPowerChanges(String deviceId, String deviceName, Map<String, dynamic> state) {
    final currentPower = <int, String>{};
    for (int i = 1; i <= 8; i++) {
      final key = 'POWER$i';
      if (state.containsKey(key)) {
        currentPower[i] = state[key].toString().toUpperCase();
      }
    }

    if (currentPower.isEmpty) return;

    final previous = _lastPower[deviceId];
    _lastPower[deviceId] = currentPower;

    // Skip first observation
    if (previous == null) return;

    for (final entry in currentPower.entries) {
      final prevValue = previous[entry.key];
      if (prevValue != null && prevValue != entry.value) {
        final channelLabel = currentPower.length == 1
            ? deviceName
            : '$deviceName Ch${entry.key}';
        final stateStr = entry.value == 'ON' ? 'Turned ON' : 'Turned OFF';

        _log.log(
          deviceId: deviceId,
          deviceName: deviceName,
          eventType: ActivityEventType.stateChange,
          description: '$channelLabel $stateStr',
        );
      }
    }
  }

  bool? _extractOnline(Map<String, dynamic> state) {
    if (state.containsKey('online')) {
      final v = state['online'];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true' || v.toLowerCase() == 'online';
    }
    if (state.containsKey('health')) {
      return (state['health'] as String).toUpperCase() == 'ONLINE';
    }
    return null;
  }

  /// Log a manual event (scene execution, device add, etc.)
  void logEvent({
    String? deviceId,
    required String deviceName,
    required ActivityEventType eventType,
    required String description,
    String? details,
  }) {
    _log.log(
      deviceId: deviceId,
      deviceName: deviceName,
      eventType: eventType,
      description: description,
      details: details,
    );
  }
}
