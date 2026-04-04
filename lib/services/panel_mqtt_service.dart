import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'enhanced_mqtt_service.dart';

/// Callback types for panel MQTT events
typedef RelayStateCallback = void Function(String panelDeviceId, int relayIndex, bool isOn);
typedef SceneTriggerCallback = void Function(String panelDeviceId, String sceneId);

/// Service that handles panel-specific MQTT topics.
///
/// Topic contract (agreed with smarty agent):
///   Control:  hbot/panels/{id}/relay/{n}/set    app→panel  "true"/"false"
///   State:    hbot/panels/{id}/relay/{n}/state   panel→app  "true"/"false"  [retain]
///   Config:   hbot/panels/{id}/config            app→panel  JSON            [retain]
///   Scene:    hbot/panels/{id}/scene/{id}/trigger panel→app "1"             [QoS1, no retain]
class PanelMqttService {
  static PanelMqttService? _instance;
  factory PanelMqttService() => _instance ??= PanelMqttService._();
  PanelMqttService._();

  final EnhancedMqttService _mqtt = EnhancedMqttService();

  // Listeners
  final List<RelayStateCallback> _relayStateListeners = [];
  final List<SceneTriggerCallback> _sceneTriggerListeners = [];

  // Track subscribed panels
  final Set<String> _subscribedPanels = {};

  // Current relay states: panelId -> {relayIndex -> isOn}
  final Map<String, Map<int, bool>> _relayStates = {};

  /// Subscribe to a panel's relay state and scene trigger topics
  void subscribeToPanel(String panelDeviceId) {
    if (_subscribedPanels.contains(panelDeviceId)) return;
    _subscribedPanels.add(panelDeviceId);

    // Subscribe to all relay states via wildcard
    final stateTopic = 'hbot/panels/$panelDeviceId/relay/+/state';
    final sceneTopic = 'hbot/panels/$panelDeviceId/scene/+/trigger';

    _mqtt.subscribeToCustomTopic(stateTopic, _handleRelayState);
    _mqtt.subscribeToCustomTopic(sceneTopic, _handleSceneTrigger);

    debugPrint('PanelMqtt: subscribed to $panelDeviceId');
  }

  /// Unsubscribe from a panel's topics
  void unsubscribeFromPanel(String panelDeviceId) {
    if (!_subscribedPanels.remove(panelDeviceId)) return;

    _mqtt.unsubscribeFromCustomTopic('hbot/panels/$panelDeviceId/relay/+/state');
    _mqtt.unsubscribeFromCustomTopic('hbot/panels/$panelDeviceId/scene/+/trigger');
    _relayStates.remove(panelDeviceId);

    debugPrint('PanelMqtt: unsubscribed from $panelDeviceId');
  }

  /// Toggle a relay on the panel
  void setRelay(String panelDeviceId, int relayIndex, bool on) {
    final topic = 'hbot/panels/$panelDeviceId/relay/$relayIndex/set';
    _mqtt.publishMessage(topic, on ? 'true' : 'false');
    debugPrint('PanelMqtt: set relay $relayIndex=${on ? "ON" : "OFF"} on $panelDeviceId');
  }

  /// Push display config to a panel (retained)
  void pushConfig(String panelDeviceId, Map<String, dynamic> config) {
    final topic = 'hbot/panels/$panelDeviceId/config';
    _mqtt.publishRetained(topic, jsonEncode(config));
    debugPrint('PanelMqtt: pushed config to $panelDeviceId');
  }

  /// Get current relay state (from cache)
  bool? getRelayState(String panelDeviceId, int relayIndex) {
    return _relayStates[panelDeviceId]?[relayIndex];
  }

  /// Add relay state listener
  void addRelayStateListener(RelayStateCallback cb) => _relayStateListeners.add(cb);
  void removeRelayStateListener(RelayStateCallback cb) => _relayStateListeners.remove(cb);

  /// Add scene trigger listener
  void addSceneTriggerListener(SceneTriggerCallback cb) => _sceneTriggerListeners.add(cb);
  void removeSceneTriggerListener(SceneTriggerCallback cb) => _sceneTriggerListeners.remove(cb);

  /// Handle incoming relay state message
  /// Topic format: hbot/panels/{panelId}/relay/{n}/state
  void _handleRelayState(String topic, String payload) {
    final parts = topic.split('/');
    // Expected: [hbot, panels, {id}, relay, {n}, state]
    if (parts.length != 6) return;

    final panelId = parts[2];
    final relayIndex = int.tryParse(parts[4]);
    if (relayIndex == null) return;

    final isOn = payload.toLowerCase() == 'true' || payload == '1' || payload.toUpperCase() == 'ON';

    _relayStates.putIfAbsent(panelId, () => {});
    _relayStates[panelId]![relayIndex] = isOn;

    for (final cb in _relayStateListeners) {
      try {
        cb(panelId, relayIndex, isOn);
      } catch (e) {
        debugPrint('PanelMqtt: relay state callback error: $e');
      }
    }
  }

  /// Handle incoming scene trigger from panel
  /// Topic format: hbot/panels/{panelId}/scene/{sceneId}/trigger
  void _handleSceneTrigger(String topic, String payload) {
    final parts = topic.split('/');
    // Expected: [hbot, panels, {id}, scene, {sceneId}, trigger]
    if (parts.length != 6) return;

    final panelId = parts[2];
    final sceneId = parts[4];

    debugPrint('PanelMqtt: scene trigger from $panelId — scene $sceneId');

    for (final cb in _sceneTriggerListeners) {
      try {
        cb(panelId, sceneId);
      } catch (e) {
        debugPrint('PanelMqtt: scene trigger callback error: $e');
      }
    }
  }
}
