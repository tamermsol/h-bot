import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ha_entity.dart';
import '../repos/ha_repo.dart';
import 'ha_websocket_service.dart';
import 'enhanced_mqtt_service.dart';

/// Bridges HA entity states to the H-Bot panel via MQTT.
///
/// When HA entities change state, this service publishes updates to
/// `hbot/panels/{panel_id}/ha/state/{entity_id}` so the panel can
/// display multi-vendor devices.
///
/// Also listens for `hbot/panels/{panel_id}/ha/command` messages from
/// the panel and forwards them as HA service calls.
class HaMqttBridgeService {
  static HaMqttBridgeService? _instance;
  factory HaMqttBridgeService() => _instance ??= HaMqttBridgeService._();
  HaMqttBridgeService._();

  final EnhancedMqttService _mqtt = EnhancedMqttService();
  final HaRepo _repo = HaRepo(Supabase.instance.client);

  HaWebSocketService? _ws;
  StreamSubscription<HaEntityState>? _stateSub;
  final Set<String> _bridgedPanels = {};
  List<HaEntity> _entities = [];

  bool get isActive => _ws != null && _ws!.isConnected;

  /// Start the bridge for a specific panel.
  /// Connects to HA, subscribes to state changes, and publishes to MQTT.
  Future<void> startBridge(String panelDeviceId) async {
    if (_bridgedPanels.contains(panelDeviceId)) return;

    final conn = await _repo.getActiveConnection();
    if (conn == null) return;

    // Connect to HA if not already
    if (_ws == null || !_ws!.isConnected) {
      _ws = HaWebSocketService();
      final connected = await _ws!.connect(conn);
      if (!connected) {
        debugPrint('[HA Bridge] Failed to connect to HA');
        return;
      }

      // Wait for auth
      await _ws!.connectionState
          .firstWhere((s) =>
              s == HaConnectionState.connected ||
              s == HaConnectionState.authFailed)
          .timeout(const Duration(seconds: 10));

      if (!_ws!.isConnected) return;

      // Subscribe to state changes
      await _ws!.subscribeStateChanges();

      // Load entities
      _entities = await _repo.getEntities();

      // Listen for state changes and relay to MQTT
      _stateSub?.cancel();
      _stateSub = _ws!.stateChanges.listen((state) {
        _relayStateToPanel(panelDeviceId, state);
      });
    }

    _bridgedPanels.add(panelDeviceId);

    // Subscribe to panel commands
    final cmdTopic = 'hbot/panels/$panelDeviceId/ha/command';
    _mqtt.subscribeToCustomTopic(cmdTopic, (topic, payload) {
      _handlePanelCommand(payload);
    });

    // Push full entity list to panel
    await _publishEntityList(panelDeviceId);

    // Push current states
    await _publishAllStates(panelDeviceId);

    debugPrint('[HA Bridge] Started for panel $panelDeviceId '
        '(${_entities.length} entities)');
  }

  /// Stop the bridge for a specific panel
  void stopBridge(String panelDeviceId) {
    _bridgedPanels.remove(panelDeviceId);
    _mqtt.unsubscribeFromCustomTopic(
        'hbot/panels/$panelDeviceId/ha/command');

    if (_bridgedPanels.isEmpty) {
      _stateSub?.cancel();
      _stateSub = null;
      _ws?.disconnect();
      _ws?.dispose();
      _ws = null;
    }

    debugPrint('[HA Bridge] Stopped for panel $panelDeviceId');
  }

  /// Publish the entity list to the panel
  Future<void> _publishEntityList(String panelDeviceId) async {
    final entityList = _entities
        .where((e) => e.isVisible)
        .map((e) => {
              'entity_id': e.entityId,
              'domain': e.domain,
              'name': e.displayName,
              'area': e.haAreaName,
            })
        .toList();

    final topic = 'hbot/panels/$panelDeviceId/ha/entities';
    _mqtt.publishMessage(topic, jsonEncode(entityList));
  }

  /// Publish all current states to the panel
  Future<void> _publishAllStates(String panelDeviceId) async {
    if (_ws == null || !_ws!.isConnected) return;

    try {
      final states = await _ws!.getStates();
      final entityIds = _entities.map((e) => e.entityId).toSet();

      for (final state in states) {
        if (entityIds.contains(state.entityId)) {
          _publishState(panelDeviceId, state);
        }
      }
    } catch (e) {
      debugPrint('[HA Bridge] Failed to publish states: $e');
    }
  }

  /// Relay a single entity state change to MQTT
  void _relayStateToPanel(String panelDeviceId, HaEntityState state) {
    // Only relay entities the user has imported
    final isImported = _entities.any((e) => e.entityId == state.entityId);
    if (!isImported) return;

    _publishState(panelDeviceId, state);
  }

  void _publishState(String panelDeviceId, HaEntityState state) {
    final payload = <String, dynamic>{
      'entity_id': state.entityId,
      'state': state.state,
    };

    // Add domain-specific attributes
    if (state.brightness != null) payload['brightness'] = state.brightness;
    if (state.colorTempKelvin != null) {
      payload['color_temp_kelvin'] = state.colorTempKelvin;
    }
    final currentTemp = state.attributes['current_temperature'];
    if (currentTemp != null) payload['current_temperature'] = currentTemp;
    final position = state.attributes['current_position'];
    if (position != null) payload['position'] = position;
    final unit = state.unitOfMeasurement;
    if (unit != null) payload['unit'] = unit;

    final topic =
        'hbot/panels/$panelDeviceId/ha/state/${state.entityId}';
    _mqtt.publishMessage(topic, jsonEncode(payload));
  }

  /// Handle a command from the panel (turn on, set temp, etc.)
  void _handlePanelCommand(String payload) {
    try {
      final cmd = jsonDecode(payload) as Map<String, dynamic>;
      final entityId = cmd['entity_id'] as String?;
      final service = cmd['service'] as String?;
      final data = cmd['data'] as Map<String, dynamic>?;

      if (entityId == null || service == null || _ws == null) return;

      final domain = entityId.split('.').first;
      _ws!.callService(
        domain: domain,
        service: service,
        entityId: entityId,
        serviceData: data,
      );

      debugPrint('[HA Bridge] Forwarded command: $domain.$service -> $entityId');
    } catch (e) {
      debugPrint('[HA Bridge] Invalid command: $e');
    }
  }

  void dispose() {
    for (final panelId in _bridgedPanels.toList()) {
      stopBridge(panelId);
    }
  }
}
