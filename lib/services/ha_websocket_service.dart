import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../models/ha_connection.dart';
import '../models/ha_entity.dart';

/// Home Assistant WebSocket API client.
/// Handles authentication, state subscriptions, and service calls.
class HaWebSocketService {
  WebSocket? _socket;
  HaConnection? _connection;
  int _msgId = 0;
  bool _authenticated = false;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _stateController = StreamController<HaEntityState>.broadcast();
  final _connectionStateController =
      StreamController<HaConnectionState>.broadcast();
  final Map<int, Completer<Map<String, dynamic>>> _pendingRequests = {};

  /// Stream of real-time entity state changes
  Stream<HaEntityState> get stateChanges => _stateController.stream;

  /// Stream of connection state changes
  Stream<HaConnectionState> get connectionState =>
      _connectionStateController.stream;

  bool get isConnected => _authenticated && _socket != null;

  /// Connect to a Home Assistant instance via WebSocket
  Future<bool> connect(HaConnection connection) async {
    _connection = connection;
    _connectionStateController.add(HaConnectionState.connecting);

    try {
      _socket = await WebSocket.connect(
        connection.wsUrl,
        headers: {'Origin': connection.baseUrl},
      ).timeout(const Duration(seconds: 10));

      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      return true;
    } catch (e) {
      debugPrint('[HA WS] Connection failed: $e');
      _connectionStateController.add(HaConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect and clean up
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _authenticated = false;
    _reconnectAttempts = 0;
    _socket?.close();
    _socket = null;
    _pendingRequests.clear();
    _connectionStateController.add(HaConnectionState.disconnected);
  }

  /// Fetch all entity states
  Future<List<HaEntityState>> getStates() async {
    final result = await _sendCommand({'type': 'get_states'});
    final states = result['result'] as List<dynamic>? ?? [];
    return states.map((s) {
      final map = s as Map<String, dynamic>;
      return HaEntityState(
        entityId: map['entity_id'] as String,
        state: (map['state'] ?? 'unknown') as String,
        attributes:
            (map['attributes'] as Map<String, dynamic>?) ?? const {},
        lastChanged:
            DateTime.tryParse((map['last_changed'] ?? '') as String) ??
                DateTime.now(),
      );
    }).toList();
  }

  /// Fetch HA config (version, location, components)
  Future<Map<String, dynamic>> getConfig() async {
    final result = await _sendCommand({'type': 'get_config'});
    return result['result'] as Map<String, dynamic>? ?? {};
  }

  /// Fetch device registry
  Future<List<Map<String, dynamic>>> getDeviceRegistry() async {
    final result =
        await _sendCommand({'type': 'config/device_registry/list'});
    final devices = result['result'] as List<dynamic>? ?? [];
    return devices.cast<Map<String, dynamic>>();
  }

  /// Fetch entity registry
  Future<List<Map<String, dynamic>>> getEntityRegistry() async {
    final result =
        await _sendCommand({'type': 'config/entity_registry/list'});
    final entities = result['result'] as List<dynamic>? ?? [];
    return entities.cast<Map<String, dynamic>>();
  }

  /// Fetch area registry
  Future<List<Map<String, dynamic>>> getAreaRegistry() async {
    final result =
        await _sendCommand({'type': 'config/area_registry/list'});
    final areas = result['result'] as List<dynamic>? ?? [];
    return areas.cast<Map<String, dynamic>>();
  }

  /// Subscribe to all state_changed events
  Future<void> subscribeStateChanges() async {
    await _sendCommand({
      'type': 'subscribe_events',
      'event_type': 'state_changed',
    });
  }

  /// Call a Home Assistant service (e.g., turn on a light)
  Future<Map<String, dynamic>> callService({
    required String domain,
    required String service,
    String? entityId,
    Map<String, dynamic>? serviceData,
  }) async {
    final cmd = <String, dynamic>{
      'type': 'call_service',
      'domain': domain,
      'service': service,
    };

    if (entityId != null) {
      cmd['target'] = {'entity_id': entityId};
    }

    if (serviceData != null && serviceData.isNotEmpty) {
      cmd['service_data'] = serviceData;
    }

    final result = await _sendCommand(cmd);
    return result;
  }

  /// Toggle an entity on/off
  Future<void> toggle(String entityId) async {
    final domain = entityId.split('.').first;
    await callService(
      domain: domain,
      service: 'toggle',
      entityId: entityId,
    );
  }

  /// Turn on an entity with optional data
  Future<void> turnOn(String entityId,
      {Map<String, dynamic>? data}) async {
    final domain = entityId.split('.').first;
    await callService(
      domain: domain,
      service: 'turn_on',
      entityId: entityId,
      serviceData: data,
    );
  }

  /// Turn off an entity
  Future<void> turnOff(String entityId) async {
    final domain = entityId.split('.').first;
    await callService(
      domain: domain,
      service: 'turn_off',
      entityId: entityId,
    );
  }

  /// Set light brightness (0-255)
  Future<void> setLightBrightness(String entityId, int brightness) async {
    await callService(
      domain: 'light',
      service: 'turn_on',
      entityId: entityId,
      serviceData: {'brightness': brightness.clamp(0, 255)},
    );
  }

  /// Set climate temperature
  Future<void> setClimateTemperature(
      String entityId, double temperature) async {
    await callService(
      domain: 'climate',
      service: 'set_temperature',
      entityId: entityId,
      serviceData: {'temperature': temperature},
    );
  }

  /// Set cover position (0-100)
  Future<void> setCoverPosition(String entityId, int position) async {
    await callService(
      domain: 'cover',
      service: 'set_cover_position',
      entityId: entityId,
      serviceData: {'position': position.clamp(0, 100)},
    );
  }

  // --- Private methods ---

  int get _nextId => ++_msgId;

  Future<Map<String, dynamic>> _sendCommand(
      Map<String, dynamic> command) async {
    if (_socket == null || !_authenticated) {
      throw StateError('Not connected to Home Assistant');
    }

    final id = _nextId;
    command['id'] = id;

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    _socket!.add(jsonEncode(command));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('HA command timed out', const Duration(seconds: 30));
      },
    );
  }

  void _onMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'auth_required':
          _authenticate();
          break;
        case 'auth_ok':
          _onAuthOk(msg);
          break;
        case 'auth_invalid':
          debugPrint('[HA WS] Auth failed: ${msg['message']}');
          _connectionStateController.add(HaConnectionState.authFailed);
          break;
        case 'result':
          _handleResult(msg);
          break;
        case 'event':
          _handleEvent(msg);
          break;
        case 'pong':
          // Keepalive response — no action needed
          break;
      }
    } catch (e) {
      debugPrint('[HA WS] Message parse error: $e');
    }
  }

  void _authenticate() {
    final token = _connection?.accessToken;
    if (token == null) {
      debugPrint('[HA WS] No access token available');
      _connectionStateController.add(HaConnectionState.authFailed);
      return;
    }

    _socket?.add(jsonEncode({
      'type': 'auth',
      'access_token': token,
    }));
  }

  void _onAuthOk(Map<String, dynamic> msg) {
    _authenticated = true;
    _reconnectAttempts = 0;
    _connectionStateController.add(HaConnectionState.connected);
    _startPingTimer();
    debugPrint(
        '[HA WS] Connected to HA ${msg['ha_version'] ?? 'unknown'}');
  }

  void _handleResult(Map<String, dynamic> msg) {
    final id = msg['id'] as int?;
    if (id == null) return;

    final completer = _pendingRequests.remove(id);
    if (completer == null) return;

    final success = msg['success'] as bool? ?? false;
    if (success) {
      completer.complete(msg);
    } else {
      final error = msg['error'] as Map<String, dynamic>?;
      completer.completeError(HaApiException(
        code: error?['code'] as String? ?? 'unknown',
        message: error?['message'] as String? ?? 'Unknown error',
      ));
    }
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final event = msg['event'] as Map<String, dynamic>?;
    if (event == null) return;

    final eventType = event['event_type'] as String?;
    if (eventType == 'state_changed') {
      final data = event['data'] as Map<String, dynamic>?;
      if (data != null) {
        final entityState = HaEntityState.fromWsEvent(data);
        _stateController.add(entityState);
      }
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_socket != null && _authenticated) {
        final id = _nextId;
        _socket!.add(jsonEncode({'id': id, 'type': 'ping'}));
      }
    });
  }

  void _onError(dynamic error) {
    debugPrint('[HA WS] Socket error: $error');
    _connectionStateController.add(HaConnectionState.error);
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('[HA WS] Socket closed');
    _authenticated = false;
    _pingTimer?.cancel();
    _connectionStateController.add(HaConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_connection == null) return;
    _reconnectTimer?.cancel();

    final delay = Duration(
      seconds: (_reconnectAttempts < 5)
          ? (1 << _reconnectAttempts) // exponential: 1, 2, 4, 8, 16
          : 30, // cap at 30s
    );
    _reconnectAttempts++;

    debugPrint('[HA WS] Reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (_connection != null) connect(_connection!);
    });
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _connectionStateController.close();
  }
}

/// Connection state enum
enum HaConnectionState {
  disconnected,
  connecting,
  connected,
  authFailed,
  error,
}

/// HA API error
class HaApiException implements Exception {
  final String code;
  final String message;

  const HaApiException({required this.code, required this.message});

  @override
  String toString() => 'HaApiException($code): $message';
}
