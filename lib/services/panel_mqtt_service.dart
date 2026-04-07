import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Callback types for panel MQTT events
typedef RelayStateCallback = void Function(String panelDeviceId, int relayIndex, bool isOn);
typedef SceneTriggerCallback = void Function(String panelDeviceId, String sceneId);

/// Service that handles panel-specific MQTT topics.
///
/// Connects to EMQX Cloud (same broker as EnhancedMqttService) so that the
/// Flutter app and the ESP32 panel are on the same broker after firmware v3.6.0.
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

  // EMQX Cloud broker — same as EnhancedMqttService (panel firmware v3.6.0+)
  static const String _panelBrokerHost = 'y3ae1177.ala.eu-central-1.emqxsl.com';
  static const int _panelBrokerPort = 8883;
  static const String _panelBrokerUsername = 'admin';
  static const String _panelBrokerPassword = 'P@ssword1';

  MqttServerClient? _client;
  bool _isConnecting = false;
  final List<RelayStateCallback> _relayStateListeners = [];
  final List<SceneTriggerCallback> _sceneTriggerListeners = [];

  // Track subscribed panels
  final Set<String> _subscribedPanels = {};

  // Topic -> custom handler mapping
  final Map<String, void Function(String, String)> _customHandlers = {};

  // Current relay states: panelId -> {relayIndex -> isOn}
  final Map<String, Map<int, bool>> _relayStates = {};

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // ─── Connection ──────────────────────────────────────────────────────────

  Future<void> _ensureConnected() async {
    if (isConnected) return;
    if (_isConnecting) {
      // Wait briefly for the in-progress connect to complete
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (isConnected) return;
      }
      return;
    }
    await _connect();
  }

  Future<void> _connect() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final clientId = 'hbot-app-panel-${Random().nextInt(99999)}';
      _client = MqttServerClient(_panelBrokerHost, clientId)
        ..port = _panelBrokerPort
        ..secure = true // TLS for EMQX Cloud port 8883
        ..keepAlivePeriod = 60
        ..connectTimeoutPeriod = 10000
        ..logging(on: kDebugMode)
        ..autoReconnect = true
        ..resubscribeOnAutoReconnect = true;

      _client!.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .authenticateAs(_panelBrokerUsername, _panelBrokerPassword)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnected = _onAutoReconnected;

      final result = await _client!.connect();
      if (result?.state != MqttConnectionState.connected) {
        debugPrint('PanelMqtt: connect failed: ${result?.state}');
        _client?.disconnect();
        _client = null;
      }
    } catch (e) {
      debugPrint('PanelMqtt: connect error: $e');
      _client?.disconnect();
      _client = null;
    } finally {
      _isConnecting = false;
    }
  }

  void _onConnected() {
    debugPrint('PanelMqtt: connected to $_panelBrokerHost:$_panelBrokerPort');
    _client!.updates!.listen(_onMessage);
    // Re-subscribe to all panels
    for (final panelId in _subscribedPanels) {
      _subscribePanel(panelId);
    }
    // Re-subscribe custom topics
    for (final topic in _customHandlers.keys) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void _onDisconnected() {
    debugPrint('PanelMqtt: disconnected');
  }

  void _onAutoReconnected() {
    debugPrint('PanelMqtt: auto-reconnected');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (msg.payload as MqttPublishMessage).payload.message,
      );

      // Dispatch to custom handlers first
      final handler = _customHandlers[topic];
      if (handler != null) {
        handler(topic, payload);
        continue;
      }

      // Try wildcard custom handlers
      for (final entry in _customHandlers.entries) {
        if (_topicMatchesPattern(topic, entry.key)) {
          entry.value(topic, payload);
        }
      }

      // Panel relay state: hbot/panels/{id}/relay/{n}/state
      final relayMatch = _parseRelayStateTopic(topic);
      if (relayMatch != null) {
        _handleRelayState(topic, payload);
        continue;
      }

      // Panel scene trigger: hbot/panels/{id}/scene/{sceneId}/trigger
      if (topic.contains('/scene/') && topic.endsWith('/trigger')) {
        _handleSceneTrigger(topic, payload);
      }
    }
  }

  // Simple MQTT wildcard pattern match (+ and #)
  bool _topicMatchesPattern(String topic, String pattern) {
    if (!pattern.contains('+') && !pattern.contains('#')) {
      return topic == pattern;
    }
    final patternParts = pattern.split('/');
    final topicParts = topic.split('/');
    for (int i = 0; i < patternParts.length; i++) {
      if (patternParts[i] == '#') return true;
      if (i >= topicParts.length) return false;
      if (patternParts[i] != '+' && patternParts[i] != topicParts[i]) {
        return false;
      }
    }
    return patternParts.length == topicParts.length;
  }

  // ─── Subscribe to Panel ───────────────────────────────────────────────────

  /// Subscribe to a panel's relay state and scene trigger topics
  Future<void> subscribeToPanel(String panelDeviceId) async {
    _subscribedPanels.add(panelDeviceId);
    await _ensureConnected();
    if (isConnected) {
      _subscribePanel(panelDeviceId);
    }
  }

  void _subscribePanel(String panelDeviceId) {
    final stateTopic = 'hbot/panels/$panelDeviceId/relay/+/state';
    final sceneTopic = 'hbot/panels/$panelDeviceId/scene/+/trigger';
    try {
      _client!.subscribe(stateTopic, MqttQos.atLeastOnce);
      _client!.subscribe(sceneTopic, MqttQos.atLeastOnce);
      debugPrint('PanelMqtt: subscribed to $panelDeviceId');
    } catch (e) {
      debugPrint('PanelMqtt: subscribe error: $e');
    }
  }

  /// Unsubscribe from a panel's topics
  void unsubscribeFromPanel(String panelDeviceId) {
    if (!_subscribedPanels.remove(panelDeviceId)) return;
    _relayStates.remove(panelDeviceId);

    if (isConnected) {
      try {
        _client!.unsubscribe('hbot/panels/$panelDeviceId/relay/+/state');
        _client!.unsubscribe('hbot/panels/$panelDeviceId/scene/+/trigger');
      } catch (_) {}
    }
    debugPrint('PanelMqtt: unsubscribed from $panelDeviceId');
  }

  // ─── Custom Topic Support (used by legacy callers that previously used EnhancedMqttService) ──

  void subscribeToCustomTopic(String topic, void Function(String, String) handler) {
    _customHandlers[topic] = handler;
    if (isConnected) {
      try { _client!.subscribe(topic, MqttQos.atLeastOnce); } catch (_) {}
    } else {
      // Trigger connect so the subscription is set up
      _ensureConnected();
    }
  }

  void unsubscribeFromCustomTopic(String topic) {
    _customHandlers.remove(topic);
    if (isConnected) {
      try { _client!.unsubscribe(topic); } catch (_) {}
    }
  }

  // ─── Publish ──────────────────────────────────────────────────────────────

  /// Toggle a relay on the panel
  Future<void> setRelay(String panelDeviceId, int relayIndex, bool on) async {
    await _ensureConnected();
    final topic = 'hbot/panels/$panelDeviceId/relay/$relayIndex/set';
    _publish(topic, on ? 'true' : 'false');
    debugPrint('PanelMqtt: set relay $relayIndex=${on ? "ON" : "OFF"} on $panelDeviceId');
  }

  /// Notify all subscribed panels that a scene was executed from the app.
  /// Publishes to: hbot/panels/{id}/scene/{sceneId}/execute with payload "1"
  Future<void> executeScene(String sceneId) async {
    if (_subscribedPanels.isEmpty) return;
    await _ensureConnected();
    if (!isConnected) return;
    for (final panelDeviceId in _subscribedPanels) {
      final topic = 'hbot/panels/$panelDeviceId/scene/$sceneId/execute';
      _publish(topic, '1');
      debugPrint('PanelMqtt: executed scene $sceneId on $panelDeviceId');
    }
  }

  /// Push display config to a panel (retained)
  Future<void> pushConfig(String panelDeviceId, Map<String, dynamic> config) async {
    await _ensureConnected();
    final topic = 'hbot/panels/$panelDeviceId/config';
    _publish(topic, jsonEncode(config), retain: true);
    debugPrint('PanelMqtt: pushed config to $panelDeviceId');
  }

  /// Publish a retained message via the persistent panel broker connection.
  /// Returns true if the message was sent.
  Future<bool> publishRetained(String topic, String payload) async {
    await _ensureConnected();
    if (!isConnected) return false;
    _publish(topic, payload, retain: true);
    return true;
  }

  void _publish(String topic, String payload, {bool retain = false}) {
    if (!isConnected) {
      debugPrint('PanelMqtt: cannot publish — not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );
  }

  // ─── State Accessors ──────────────────────────────────────────────────────

  /// Get current relay state (from cache)
  bool? getRelayState(String panelDeviceId, int relayIndex) {
    return _relayStates[panelDeviceId]?[relayIndex];
  }

  void addRelayStateListener(RelayStateCallback cb) => _relayStateListeners.add(cb);
  void removeRelayStateListener(RelayStateCallback cb) => _relayStateListeners.remove(cb);

  void addSceneTriggerListener(SceneTriggerCallback cb) => _sceneTriggerListeners.add(cb);
  void removeSceneTriggerListener(SceneTriggerCallback cb) => _sceneTriggerListeners.remove(cb);

  // ─── Message Handlers ─────────────────────────────────────────────────────

  Map<String, int>? _parseRelayStateTopic(String topic) {
    // hbot/panels/{id}/relay/{n}/state
    final parts = topic.split('/');
    if (parts.length != 6) return null;
    if (parts[0] != 'hbot' || parts[1] != 'panels' ||
        parts[3] != 'relay' || parts[5] != 'state') return null;
    final relayIndex = int.tryParse(parts[4]);
    if (relayIndex == null) return null;
    return {'relayIndex': relayIndex};
  }

  void _handleRelayState(String topic, String payload) {
    final parts = topic.split('/');
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

  void _handleSceneTrigger(String topic, String payload) {
    final parts = topic.split('/');
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

  // ─── Static Direct Publish ────────────────────────────────────────────────

  /// Publish a single retained message directly to an MQTT broker.
  ///
  /// Creates a short-lived plain-TCP connection to [broker]:[port].
  /// Pass [username] and [password] when connecting to an authenticated broker.
  /// Retries up to [maxAttempts] times on failure. Returns true on success.
  static Future<bool> publishDirect({
    required String broker,
    required int port,
    required String topic,
    required String payload,
    bool retain = true,
    MqttQos qos = MqttQos.atLeastOnce,
    int maxAttempts = 3,
    String? username,
    String? password,
    bool? secure, // null = auto-detect from port (8883 → TLS)
  }) async {
    final useTls = secure ?? (port == 8883);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      MqttServerClient? client;
      try {
        final clientId = 'hbot-panel-${Random().nextInt(99999)}';
        client = MqttServerClient(broker, clientId)
          ..port = port
          ..secure = useTls
          ..keepAlivePeriod = 10
          ..connectTimeoutPeriod = 5000
          ..logging(on: false);

        var connMsg = MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean()
            .withWillQos(MqttQos.atMostOnce);
        if (username != null && username.isNotEmpty) {
          connMsg = connMsg.authenticateAs(username, password ?? '');
        }
        client.connectionMessage = connMsg;

        final result = await client.connect();
        if (result?.state != MqttConnectionState.connected) {
          debugPrint('PanelMqtt direct: connect failed attempt ${attempt + 1}: ${result?.state}');
          client.disconnect();
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final builder = MqttClientPayloadBuilder()..addString(payload);
        client.publishMessage(topic, qos, builder.payload!, retain: retain);

        await Future.delayed(const Duration(milliseconds: 500));
        client.disconnect();

        debugPrint('PanelMqtt direct: published → $broker:$port $topic');
        return true;
      } catch (e) {
        debugPrint('PanelMqtt direct: attempt ${attempt + 1} failed: $e');
        try { client?.disconnect(); } catch (_) {}
        if (attempt < maxAttempts - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    debugPrint('PanelMqtt direct: all $maxAttempts attempts failed for $topic');
    return false;
  }
}
