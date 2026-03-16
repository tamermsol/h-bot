import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Manages home screen widget data for iOS and Android.
class HomeWidgetService {
  static const String _appGroupId = 'group.com.msol.hbot';
  static const String _androidWidgetName = 'HBotDeviceWidget';
  static const String _iOSWidgetName = 'HBotWidget';

  static Future<void> initialize() async {
    try {
      HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('⚠️ Home widget init error: $e');
    }
  }

  /// Update widget data with device states.
  /// Call this whenever device states change.
  static Future<void> updateDeviceStates(List<WidgetDevice> devices) async {
    try {
      // Store up to 4 devices for the widget
      final widgetDevices = devices.take(4).toList();

      await HomeWidget.saveWidgetData('device_count', widgetDevices.length);

      for (int i = 0; i < widgetDevices.length; i++) {
        final d = widgetDevices[i];
        await HomeWidget.saveWidgetData('device_${i}_id', d.id);
        await HomeWidget.saveWidgetData('device_${i}_name', d.name);
        await HomeWidget.saveWidgetData('device_${i}_state', d.isOn ? 'ON' : 'OFF');
        await HomeWidget.saveWidgetData('device_${i}_type', d.type);
      }

      // Trigger widget update
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('⚠️ Home widget update error: $e');
    }
  }

  /// Handle widget interaction (device toggle).
  static Future<void> handleWidgetAction(Uri? uri) async {
    if (uri == null) return;

    debugPrint('🏠 Widget action: $uri');

    final deviceId = uri.queryParameters['deviceId'];
    if (deviceId == null) return;

    // Store the pending action for the app to process
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_pending_toggle', deviceId);
  }

  /// Check and process any pending widget toggle actions.
  /// Returns (deviceId, state) if there's a pending toggle, null otherwise.
  static Future<({String deviceId, String state})?> getPendingToggle() async {
    try {
      final deviceId = await HomeWidget.getWidgetData<String>('pending_toggle_device');
      final state = await HomeWidget.getWidgetData<String>('pending_toggle_state');

      if (deviceId != null && state != null) {
        // Clear the pending action
        await HomeWidget.saveWidgetData('pending_toggle_device', null);
        await HomeWidget.saveWidgetData('pending_toggle_state', null);
        return (deviceId: deviceId, state: state);
      }
    } catch (e) {
      debugPrint('⚠️ Error reading pending toggle: $e');
    }
    return null;
  }

  /// Save favorite devices for widget display.
  static Future<void> saveFavoriteDevices(List<WidgetDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final json = devices.map((d) => d.toJson()).toList();
    await prefs.setString('widget_favorites', jsonEncode(json));
    await updateDeviceStates(devices);
  }

  /// Load favorite devices.
  static Future<List<WidgetDevice>> loadFavoriteDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('widget_favorites');
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => WidgetDevice.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}

class WidgetDevice {
  final String id;
  final String name;
  final bool isOn;
  final String type; // 'light', 'switch', 'shutter'

  WidgetDevice({
    required this.id,
    required this.name,
    required this.isOn,
    this.type = 'switch',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isOn': isOn,
    'type': type,
  };

  factory WidgetDevice.fromJson(Map<String, dynamic> json) => WidgetDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    isOn: json['isOn'] as bool? ?? false,
    type: json['type'] as String? ?? 'switch',
  );
}
