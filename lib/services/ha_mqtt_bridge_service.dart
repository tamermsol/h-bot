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

    // Subscribe to panel commands (entity control)
    final cmdTopic = 'hbot/panels/$panelDeviceId/ha/command';
    _mqtt.subscribeToCustomTopic(cmdTopic, (topic, payload) {
      _handlePanelCommand(payload);
    });

    // Subscribe to scene activation commands from panel
    final sceneTopic = 'hbot/panels/$panelDeviceId/ha/activate_scene';
    _mqtt.subscribeToCustomTopic(sceneTopic, (topic, payload) {
      _handlePanelSceneActivation(payload);
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
    _mqtt.unsubscribeFromCustomTopic(
        'hbot/panels/$panelDeviceId/ha/activate_scene');

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
    final visibleEntities = _entities.where((e) => e.isVisible).toList();

    // Publish non-scene entities
    final entityList = visibleEntities
        .where((e) => e.domain != 'scene')
        .map((e) => {
              'entity_id': e.entityId,
              'domain': e.domain,
              'name': e.displayName,
              'area': e.haAreaName,
            })
        .toList();

    final entityTopic = 'hbot/panels/$panelDeviceId/ha/entities';
    _mqtt.publishMessage(entityTopic, jsonEncode(entityList));

    // Publish scenes as a separate list so the panel can show scene buttons
    final sceneList = visibleEntities
        .where((e) => e.domain == 'scene')
        .map((e) => {
              'entity_id': e.entityId,
              'name': e.displayName,
            })
        .toList();

    if (sceneList.isNotEmpty) {
      final sceneTopic = 'hbot/panels/$panelDeviceId/ha/scenes';
      _mqtt.publishMessage(sceneTopic, jsonEncode(sceneList));
    }
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

  /// Publish a scene activation event to all bridged panels.
  /// Called by the app UI when a user activates an HA scene, so the
  /// panel can react immediately (e.g., show a toast or update its view).
  void publishSceneActivation(String sceneEntityId) {
    final payload = jsonEncode({
      'entity_id': sceneEntityId,
      'activated_at': DateTime.now().toIso8601String(),
    });

    for (final panelId in _bridgedPanels) {
      final topic = 'hbot/panels/$panelId/ha/scene_activated';
      _mqtt.publishMessage(topic, payload);
    }

    debugPrint('[HA Bridge] Published scene activation: $sceneEntityId');
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

  /// Handle a scene activation request from the panel.
  /// Expects JSON: {"entity_id": "scene.movie_night"}
  void _handlePanelSceneActivation(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final entityId = data['entity_id'] as String?;
      if (entityId == null || _ws == null) return;

      _ws!.callService(
        domain: 'scene',
        service: 'turn_on',
        entityId: entityId,
      );

      debugPrint('[HA Bridge] Panel activated scene: $entityId');
    } catch (e) {
      debugPrint('[HA Bridge] Invalid scene activation: $e');
    }
  }

  void dispose() {
    for (final panelId in _bridgedPanels.toList()) {
      stopBridge(panelId);
    }
  }
}
