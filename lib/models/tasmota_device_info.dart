import 'package:json_annotation/json_annotation.dart';

part 'tasmota_device_info.g.dart';

/// Information about a discovered Tasmota device
@JsonSerializable()
class TasmotaDeviceInfo {
  final String ip;
  final String mac;
  final String hostname;
  final String module;
  final String version;
  final int channels;
  final List<String> sensors;
  final String topicBase;
  final String fullTopic;
  final Map<String, dynamic> status;
  final bool isShutter; // NEW: Flag to indicate if device is a shutter

  const TasmotaDeviceInfo({
    required this.ip,
    required this.mac,
    required this.hostname,
    required this.module,
    required this.version,
    required this.channels,
    required this.sensors,
    required this.topicBase,
    required this.fullTopic,
    required this.status,
    this.isShutter = false, // Default to false for backward compatibility
  });

  factory TasmotaDeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$TasmotaDeviceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$TasmotaDeviceInfoToJson(this);

  /// Generate topic base from MAC address
  /// For MAC F4:12:FA:50:67:7C → topic = hbot_50677C
  static String generateTopicFromMac(String mac) {
    // Remove colons and take last 6 characters
    final cleanMac = mac.replaceAll(':', '').toUpperCase();
    final suffix = cleanMac.substring(cleanMac.length - 6);
    return 'hbot_$suffix';
  }

  /// Get command topic for a specific command
  /// Example: cmnd/hbot_50677C/POWER1
  String getCommandTopic(String command) {
    return 'cmnd/$topicBase/$command';
  }

  /// Get state topic for a specific state
  /// Example: stat/hbot_50677C/POWER1
  String getStateTopic(String state) {
    return 'stat/$topicBase/$state';
  }

  /// Get telemetry topic
  /// Example: tele/hbot_50677C/STATE
  String getTelemetryTopic(String tele) {
    return 'tele/$topicBase/$tele';
  }

  /// Get all command topics for this device
  List<String> getCommandTopics() {
    final topics = <String>[];
    for (int i = 1; i <= channels; i++) {
      topics.add(getCommandTopic('POWER$i'));
    }
    topics.addAll([
      getCommandTopic('STATUS'),
      getCommandTopic('STATE'),
      getCommandTopic('RESTART'),
    ]);
    return topics;
  }

  /// Get all state topics for this device (comprehensive for real-time sync)
  List<String> getStateTopics() {
    final topics = <String>[];

    // Individual power state topics
    for (int i = 1; i <= channels; i++) {
      topics.add(getStateTopic('POWER$i'));
    }

    // Status and state topics
    topics.addAll([
      getStateTopic('STATUS'),
      getStateTopic('STATE'),
      getStateTopic('RESULT'), // Command results and physical button presses
      getTelemetryTopic('STATE'), // Periodic state updates
      getTelemetryTopic('SENSOR'), // Sensor data
      getTelemetryTopic('LWT'), // Last Will and Testament (online/offline)
      getTelemetryTopic('RESULT'), // Telemetry results
    ]);

    return topics;
  }

  TasmotaDeviceInfo copyWith({
    String? ip,
    String? mac,
    String? hostname,
    String? module,
    String? version,
    int? channels,
    List<String>? sensors,
    String? topicBase,
    String? fullTopic,
    Map<String, dynamic>? status,
    bool? isShutter,
  }) {
    return TasmotaDeviceInfo(
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      module: module ?? this.module,
      version: version ?? this.version,
      channels: channels ?? this.channels,
      sensors: sensors ?? this.sensors,
      topicBase: topicBase ?? this.topicBase,
      fullTopic: fullTopic ?? this.fullTopic,
      status: status ?? this.status,
      isShutter: isShutter ?? this.isShutter,
    );
  }
}

/// Wi-Fi provisioning request
@JsonSerializable()
class WiFiProvisioningRequest {
  final String ssid;
  final String password;
  final String? hostname;

  const WiFiProvisioningRequest({
    required this.ssid,
    required this.password,
    this.hostname,
  });

  factory WiFiProvisioningRequest.fromJson(Map<String, dynamic> json) =>
      _$WiFiProvisioningRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WiFiProvisioningRequestToJson(this);
}

/// Wi-Fi provisioning response
@JsonSerializable()
class WiFiProvisioningResponse {
  final bool success;
  final String message;
  final String? deviceIp;

  const WiFiProvisioningResponse({
    required this.success,
    required this.message,
    this.deviceIp,
  });

  factory WiFiProvisioningResponse.fromJson(Map<String, dynamic> json) =>
      _$WiFiProvisioningResponseFromJson(json);
  Map<String, dynamic> toJson() => _$WiFiProvisioningResponseToJson(this);
}

/// Device discovery result
@JsonSerializable()
class DeviceDiscoveryResult {
  final String ip;
  final String? hostname;
  final bool isReachable;
  final int? responseTime;
  final String discoveryMethod; // 'mdns', 'sweep', 'manual'

  const DeviceDiscoveryResult({
    required this.ip,
    this.hostname,
    required this.isReachable,
    this.responseTime,
    required this.discoveryMethod,
  });

  factory DeviceDiscoveryResult.fromJson(Map<String, dynamic> json) =>
      _$DeviceDiscoveryResultFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceDiscoveryResultToJson(this);
}

/// MQTT connection status
enum MqttConnectionStatus { disconnected, connecting, connected, error }

/// Tasmota device command
@JsonSerializable()
class TasmotaCommand {
  final String topic;
  final String payload;
  final bool retain;
  final int qos;

  const TasmotaCommand({
    required this.topic,
    required this.payload,
    this.retain = false,
    this.qos = 1, // Use QoS 1 (atLeastOnce) for reliable delivery
  });

  factory TasmotaCommand.fromJson(Map<String, dynamic> json) =>
      _$TasmotaCommandFromJson(json);
  Map<String, dynamic> toJson() => _$TasmotaCommandToJson(this);

  /// Create a power command
  static TasmotaCommand power(String topicBase, int channel, bool on) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/POWER$channel',
      payload: on ? 'ON' : 'OFF',
    );
  }

  /// Create a dimmer command
  static TasmotaCommand dimmer(String topicBase, int channel, int brightness) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/DIMMER$channel',
      payload: brightness.toString(),
    );
  }

  /// Create a status query command
  static TasmotaCommand status(String topicBase, [int? statusType]) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/STATUS${statusType ?? ''}',
      payload: '',
    );
  }

  /// Create a STATE query command (read-only, gets all relay states)
  static TasmotaCommand state(String topicBase) {
    return TasmotaCommand(topic: 'cmnd/$topicBase/STATE', payload: '');
  }

  /// Create a shutter open command
  static TasmotaCommand shutterOpen(String topicBase, int shutterIndex) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/ShutterOpen$shutterIndex',
      payload: '',
    );
  }

  /// Create a shutter close command
  static TasmotaCommand shutterClose(String topicBase, int shutterIndex) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/ShutterClose$shutterIndex',
      payload: '',
    );
  }

  /// Create a shutter stop command
  static TasmotaCommand shutterStop(String topicBase, int shutterIndex) {
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/ShutterStop$shutterIndex',
      payload: '',
    );
  }

  /// Create a shutter position command (0-100)
  static TasmotaCommand shutterPosition(
    String topicBase,
    int shutterIndex,
    int position,
  ) {
    // Clamp position between 0 and 100
    final clampedPosition = position.clamp(0, 100);
    return TasmotaCommand(
      topic: 'cmnd/$topicBase/ShutterPosition$shutterIndex',
      payload: clampedPosition.toString(),
    );
  }
}
