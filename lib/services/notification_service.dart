import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles local push notifications for device events, scenes, and timers.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification channel IDs
  static const String _deviceChannelId = 'hbot_device_events';
  static const String _sceneChannelId = 'hbot_scene_events';
  static const String _systemChannelId = 'hbot_system';

  // Preference keys
  static const String _prefDeviceOffline = 'notif_device_offline';
  static const String _prefDeviceOnline = 'notif_device_online';
  static const String _prefSceneRun = 'notif_scene_run';
  static const String _prefStateChange = 'notif_state_change';

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    // In debug mode on iOS (simulator), skip auto-requesting permissions
    // to avoid the notification dialog blocking screenshots
    final bool skipIosPermission = !kIsWeb && Platform.isIOS && kDebugMode;
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: !skipIosPermission,
      requestBadgePermission: !skipIosPermission,
      requestSoundPermission: !skipIosPermission,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channels
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _deviceChannelId,
            'Device Events',
            description: 'Notifications for device online/offline status changes',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _sceneChannelId,
            'Scene Events',
            description: 'Notifications when scenes are triggered',
            importance: Importance.defaultImportance,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _systemChannelId,
            'System',
            description: 'System notifications and updates',
            importance: Importance.low,
          ),
        );
      }
    }

    // Request iOS permissions (skip in debug to avoid simulator dialog)
    if (!kIsWeb && Platform.isIOS && !kDebugMode) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
    debugPrint('🔔 NotificationService initialized');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Navigate to relevant screen based on payload
  }

  // --- Preference getters/setters ---

  Future<bool> _getPref(String key, {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<bool> get deviceOfflineEnabled => _getPref(_prefDeviceOffline);
  Future<bool> get deviceOnlineEnabled => _getPref(_prefDeviceOnline, defaultValue: false);
  Future<bool> get sceneRunEnabled => _getPref(_prefSceneRun);
  Future<bool> get stateChangeEnabled => _getPref(_prefStateChange, defaultValue: false);

  Future<void> setDeviceOfflineEnabled(bool v) => setPref(_prefDeviceOffline, v);
  Future<void> setDeviceOnlineEnabled(bool v) => setPref(_prefDeviceOnline, v);
  Future<void> setSceneRunEnabled(bool v) => setPref(_prefSceneRun, v);
  Future<void> setStateChangeEnabled(bool v) => setPref(_prefStateChange, v);

  // --- Notification senders ---

  int _notifId = 0;
  int get _nextId => _notifId++;

  Future<void> notifyDeviceOffline(String deviceName) async {
    if (!await deviceOfflineEnabled) return;
    await _show(
      title: '⚠️ Device Offline',
      body: '$deviceName has gone offline',
      channelId: _deviceChannelId,
      channelName: 'Device Events',
      payload: 'device_offline:$deviceName',
    );
  }

  Future<void> notifyDeviceOnline(String deviceName) async {
    if (!await deviceOnlineEnabled) return;
    await _show(
      title: '✅ Device Online',
      body: '$deviceName is back online',
      channelId: _deviceChannelId,
      channelName: 'Device Events',
      payload: 'device_online:$deviceName',
    );
  }

  Future<void> notifySceneExecuted(String sceneName) async {
    if (!await sceneRunEnabled) return;
    await _show(
      title: '🎬 Scene Executed',
      body: '"$sceneName" has been triggered',
      channelId: _sceneChannelId,
      channelName: 'Scene Events',
      payload: 'scene_run:$sceneName',
    );
  }

  Future<void> notifyDeviceStateChange(String deviceName, String state) async {
    if (!await stateChangeEnabled) return;
    await _show(
      title: '💡 $deviceName',
      body: state,
      channelId: _deviceChannelId,
      channelName: 'Device Events',
      payload: 'state_change:$deviceName',
    );
  }

  Future<void> notifyFirmwareAvailable(String deviceName, String version) async {
    await _show(
      title: '🔄 Firmware Update Available',
      body: '$deviceName can be updated to $version',
      channelId: _systemChannelId,
      channelName: 'System',
      payload: 'firmware:$deviceName',
    );
  }

  Future<void> _show({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      _nextId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
