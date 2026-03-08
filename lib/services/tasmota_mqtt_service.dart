import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/tasmota_device_info.dart';

/// Service for MQTT communication with Tasmota devices
class TasmotaMqttService {
  static const String _clientId = 'hbot_app';
  static const int _keepAlivePeriod = 60;
  static const Duration _connectionTimeout = Duration(seconds: 30);

  MqttServerClient? _client;
  String? _brokerHost;
  int? _brokerPort;
  String? _username;
  String? _password;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, StreamController<Map<String, dynamic>>> _deviceControllers =
      {};

  MqttConnectionStatus _connectionStatus = MqttConnectionStatus.disconnected;

  /// Stream of all MQTT messages
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Current connection status
  MqttConnectionStatus get connectionStatus => _connectionStatus;

  /// Configure MQTT broker settings
  void configure({
    required String brokerHost,
    int brokerPort = 1883,
    String? username,
    String? password,
  }) {
    _brokerHost = brokerHost;
    _brokerPort = brokerPort;
    _username = username;
    _password = password;
  }

  /// Connect to MQTT broker
  Future<bool> connect() async {
    if (_brokerHost == null || _brokerPort == null) {
      throw 'MQTT broker not configured';
    }

    try {
      _connectionStatus = MqttConnectionStatus.connecting;

      _client = MqttServerClient(_brokerHost!, _clientId);
      _client!.port = _brokerPort!;
      _client!.keepAlivePeriod = _keepAlivePeriod;
      _client!.connectTimeoutPeriod = _connectionTimeout.inMilliseconds;
      _client!.autoReconnect = true;
      _client!.resubscribeOnAutoReconnect = true;

      // Set up event handlers
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;
      _client!.onUnsubscribed = _onUnsubscribed;

      // Set up message handler
      _client!.updates!.listen(_onMessage);

      // Create connection message
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      if (_username != null && _password != null) {
        connMessage.authenticateAs(_username!, _password!);
      }

      _client!.connectionMessage = connMessage;

      // Connect
      await _client!.connect();

      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        _connectionStatus = MqttConnectionStatus.connected;
        return true;
      } else {
        _connectionStatus = MqttConnectionStatus.error;
        return false;
      }
    } catch (e) {
      _connectionStatus = MqttConnectionStatus.error;
      throw 'Failed to connect to MQTT broker: $e';
    }
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    try {
      _client?.disconnect();
      _connectionStatus = MqttConnectionStatus.disconnected;
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  /// Subscribe to device state topics
  Future<void> subscribeToDevice(TasmotaDeviceInfo device) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      throw 'MQTT client not connected';
    }

    try {
      // Subscribe to all state topics for this device with consistent QoS
      final stateTopics = device.getStateTopics();
      for (final topic in stateTopics) {
        _client!.subscribe(topic, MqttQos.atLeastOnce);
      }

      // Create device-specific stream controller if not exists
      if (!_deviceControllers.containsKey(device.topicBase)) {
        _deviceControllers[device.topicBase] =
            StreamController<Map<String, dynamic>>.broadcast();
      }
    } catch (e) {
      throw 'Failed to subscribe to device topics: $e';
    }
  }

  /// Unsubscribe from device state topics
  Future<void> unsubscribeFromDevice(TasmotaDeviceInfo device) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }

    try {
      // Unsubscribe from all state topics for this device
      final stateTopics = device.getStateTopics();
      for (final topic in stateTopics) {
        _client!.unsubscribe(topic);
      }

      // Close and remove device-specific stream controller
      _deviceControllers[device.topicBase]?.close();
      _deviceControllers.remove(device.topicBase);
    } catch (e) {
      // Ignore unsubscribe errors
    }
  }

  /// Get stream for a specific device
  Stream<Map<String, dynamic>>? getDeviceStream(String topicBase) {
    return _deviceControllers[topicBase]?.stream;
  }

  /// Send command to device
  Future<void> sendCommand(TasmotaCommand command) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      throw 'MQTT client not connected';
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(command.payload);

      _client!.publishMessage(
        command.topic,
        command.qos == 0
            ? MqttQos.atMostOnce
            : command.qos == 1
            ? MqttQos.atLeastOnce
            : MqttQos.exactlyOnce,
        builder.payload!,
        retain: command.retain,
      );
    } catch (e) {
      throw 'Failed to send command: $e';
    }
  }

  /// Turn device power on/off
  Future<void> setPower(String topicBase, int channel, bool on) async {
    final command = TasmotaCommand.power(topicBase, channel, on);
    await sendCommand(command);
  }

  /// Set dimmer brightness
  Future<void> setDimmer(String topicBase, int channel, int brightness) async {
    final command = TasmotaCommand.dimmer(topicBase, channel, brightness);
    await sendCommand(command);
  }

  /// Request device status
  Future<void> requestStatus(String topicBase, [int? statusType]) async {
    final command = TasmotaCommand.status(topicBase, statusType);
    await sendCommand(command);
  }

  /// Request device STATE (read-only, gets all relay states)
  Future<void> requestState(String topicBase) async {
    final command = TasmotaCommand.state(topicBase);
    await sendCommand(command);
  }

  /// Open shutter
  Future<void> openShutter(String topicBase, int shutterIndex) async {
    final command = TasmotaCommand.shutterOpen(topicBase, shutterIndex);
    await sendCommand(command);
  }

  /// Close shutter
  Future<void> closeShutter(String topicBase, int shutterIndex) async {
    final command = TasmotaCommand.shutterClose(topicBase, shutterIndex);
    await sendCommand(command);
  }

  /// Stop shutter
  Future<void> stopShutter(String topicBase, int shutterIndex) async {
    final command = TasmotaCommand.shutterStop(topicBase, shutterIndex);
    await sendCommand(command);
  }

  /// Set shutter position (0-100)
  Future<void> setShutterPosition(
    String topicBase,
    int shutterIndex,
    int position,
  ) async {
    final command = TasmotaCommand.shutterPosition(
      topicBase,
      shutterIndex,
      position,
    );
    await sendCommand(command);
  }

  /// Test MQTT connectivity with a device
  Future<bool> testDeviceConnectivity(TasmotaDeviceInfo device) async {
    try {
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        await connect();
      }

      // Subscribe to device state topics
      await subscribeToDevice(device);

      // Send a harmless status query
      await requestStatus(device.topicBase);

      // Wait for response (with timeout)
      final deviceStream = getDeviceStream(device.topicBase);
      if (deviceStream != null) {
        await deviceStream.first.timeout(const Duration(seconds: 10));
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Event handlers
  void _onConnected() {
    _connectionStatus = MqttConnectionStatus.connected;
  }

  void _onDisconnected() {
    _connectionStatus = MqttConnectionStatus.disconnected;
  }

  void _onSubscribed(String topic) {
    // Topic subscribed successfully
  }

  void _onUnsubscribed(String? topic) {
    // Topic unsubscribed successfully
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      try {
        // Try to parse as JSON
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final messageData = {
          'topic': topic,
          'payload': data,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Send to main stream
        _messageController.add(messageData);

        // Send to device-specific stream if applicable
        final topicParts = topic.split('/');
        if (topicParts.length >= 2) {
          final topicBase = topicParts[1];
          _deviceControllers[topicBase]?.add(messageData);
        }
      } catch (e) {
        // Not JSON, send as string
        final messageData = {
          'topic': topic,
          'payload': payload,
          'timestamp': DateTime.now().toIso8601String(),
        };

        _messageController.add(messageData);

        // Send to device-specific stream if applicable
        final topicParts = topic.split('/');
        if (topicParts.length >= 2) {
          final topicBase = topicParts[1];
          _deviceControllers[topicBase]?.add(messageData);
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _messageController.close();
    for (final controller in _deviceControllers.values) {
      controller.close();
    }
    _deviceControllers.clear();
  }
}
