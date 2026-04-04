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

  /// Load the widget slot configuration saved by the native config activity.
  /// Returns a list of slot configs: {deviceId, channel, channelLabel, type, topic, totalChannels}
  static Future<List<Map<String, dynamic>>> loadWidgetSlots() async {
    try {
      // Native config saves to HomeWidgetPreferences via getSharedPreferences
      // home_widget package also uses HomeWidgetPreferences, so getWidgetData works
      final raw = await HomeWidget.getWidgetData<String>('widget_slots_json');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        return list.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Update widget slot states based on current MQTT data.
  /// This ONLY updates the ON/OFF state — never overwrites device/channel/name config.
  /// [mqttStates] maps deviceId -> MQTT state map (e.g. {'POWER1': 'ON', 'POWER2': 'OFF'})
  static Future<void> updateWidgetStates(Map<String, Map<String, dynamic>> mqttStates) async {
    try {
      final slotsJson = await HomeWidget.getWidgetData<String>('widget_slots_json');

      if (slotsJson == null || slotsJson.isEmpty) {
        // No widget configured — nothing to update
        return;
      }

      List<dynamic> slots;
      try {
        slots = jsonDecode(slotsJson) as List;
      } catch (_) {
        return;
      }

      final count = slots.length.clamp(0, 4);
      await HomeWidget.saveWidgetData('device_count', count);

      for (int i = 0; i < count; i++) {
        final slot = slots[i] as Map<String, dynamic>;
        final deviceId = slot['deviceId'] as String? ?? '';
        final channel = slot['channel'] as int? ?? 0;
        final channelLabel = slot['channelLabel'] as String? ?? 'Device';
        final type = slot['type'] as String? ?? 'switch';
        final topic = slot['topic'] as String? ?? '';
        final totalChannels = slot['totalChannels'] as int? ?? 1;

        // Determine ON/OFF from MQTT state for this specific channel
        bool isOn = false;
        final state = mqttStates[deviceId];
        if (state != null) {
          if (channel == 0) {
            // Bulk: ON if any channel is ON
            if (state['POWER'] == 'ON' || state['POWER'] == true) isOn = true;
            for (int ch = 1; ch <= totalChannels; ch++) {
              if (state['POWER$ch'] == 'ON' || state['POWER$ch'] == true) {
                isOn = true;
                break;
              }
            }
          } else {
            // Specific channel
            isOn = state['POWER$channel'] == 'ON' || state['POWER$channel'] == true;
          }
        }
        // onlineCount tracking removed — not currently used

        // Use latest channel label from local storage if available
        String displayName = channelLabel;
        if (channel > 0) {
          final prefs = await SharedPreferences.getInstance();
          final localLabel = prefs.getString('channel_label_${deviceId}_$channel');
          if (localLabel != null && localLabel.isNotEmpty) {
            // Extract device base name (before " · ") and append new label
            final baseName = channelLabel.contains(' · ')
                ? channelLabel.split(' · ').first
                : channelLabel;
            displayName = '$baseName · $localLabel';
          }
        }

        await HomeWidget.saveWidgetData('device_${i}_id', deviceId);
        await HomeWidget.saveWidgetData('device_${i}_name', displayName);
        await HomeWidget.saveWidgetData('device_${i}_state', isOn ? 'ON' : 'OFF');
        await HomeWidget.saveWidgetData('device_${i}_type', type);
        await HomeWidget.saveWidgetData('device_${i}_topic', topic);
        await HomeWidget.saveWidgetData('device_${i}_channels', totalChannels.toString());
        await HomeWidget.saveWidgetData('device_${i}_channel', channel.toString());
      }

      // Trigger widget refresh
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      debugPrint('⚠️ Home widget state update error: $e');
    }
  }

  /// Store all available devices so the native widget config activity can read them.
  /// [channelLabels] maps deviceId -> {channelNo -> label}
  static Future<void> saveAllDevicesForConfig(
    List<WidgetDevice> allDevices, {
    Map<String, Map<int, String>>? channelLabels,
  }) async {
    try {
      final jsonList = allDevices.map((d) {
        final map = d.toJson();
        // Include channel labels if available
        if (channelLabels != null && channelLabels.containsKey(d.id)) {
          final labels = channelLabels[d.id]!;
          map['channelLabels'] = labels.map((k, v) => MapEntry(k.toString(), v));
        }
        return map;
      }).toList();
      await HomeWidget.saveWidgetData('all_devices_json', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('⚠️ Error saving devices for widget config: $e');
    }
  }

  /// Handle widget interaction (device toggle).
  static Future<void> handleWidgetAction(Uri? uri) async {
    if (uri == null) return;
    debugPrint('🏠 Widget action: $uri');
    final deviceId = uri.queryParameters['deviceId'];
    if (deviceId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_pending_toggle', deviceId);
  }

  /// Check and process any pending widget toggle actions.
  static Future<({String deviceId, String state})?> getPendingToggle() async {
    try {
      final deviceId = await HomeWidget.getWidgetData<String>('pending_toggle_device');
      final state = await HomeWidget.getWidgetData<String>('pending_toggle_state');
      if (deviceId != null && state != null) {
        await HomeWidget.saveWidgetData('pending_toggle_device', null);
        await HomeWidget.saveWidgetData('pending_toggle_state', null);
        return (deviceId: deviceId, state: state);
      }
    } catch (e) {
      debugPrint('⚠️ Error reading pending toggle: $e');
    }
    return null;
  }
}

class WidgetDevice {
  final String id;
  final String name;
  final bool isOn;
  final String type;
  final String topicBase;
  final int channels;

  WidgetDevice({
    required this.id,
    required this.name,
    required this.isOn,
    this.type = 'switch',
    this.topicBase = '',
    this.channels = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isOn': isOn,
    'type': type,
    'topicBase': topicBase,
    'channels': channels,
  };

  factory WidgetDevice.fromJson(Map<String, dynamic> json) => WidgetDevice(
    id: json['id'] as String,
    name: json['name'] as String,
    isOn: json['isOn'] as bool? ?? false,
    type: json['type'] as String? ?? 'switch',
    topicBase: json['topicBase'] as String? ?? '',
    channels: json['channels'] as int? ?? 1,
  );
}
