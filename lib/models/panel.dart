import 'package:json_annotation/json_annotation.dart';

part 'panel.g.dart';

@JsonSerializable()
class Panel {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'broker_address')
  final String brokerAddress;
  @JsonKey(name: 'broker_port')
  final int brokerPort;
  @JsonKey(name: 'pairing_token')
  final String pairingToken;
  @JsonKey(name: 'owner_user_id')
  final String ownerUserId;
  @JsonKey(name: 'home_id')
  final String? homeId;
  @JsonKey(name: 'household_id')
  final String householdId;
  @JsonKey(name: 'display_config')
  final Map<String, dynamic>? displayConfig;
  @JsonKey(name: 'paired_at')
  final DateTime? pairedAt;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const Panel({
    required this.id,
    required this.deviceId,
    required this.displayName,
    required this.brokerAddress,
    this.brokerPort = 1883,
    required this.pairingToken,
    required this.ownerUserId,
    this.homeId,
    required this.householdId,
    this.displayConfig,
    this.pairedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Panel.fromJson(Map<String, dynamic> json) => _$PanelFromJson(json);
  Map<String, dynamic> toJson() => _$PanelToJson(this);

  Panel copyWith({
    String? id,
    String? deviceId,
    String? displayName,
    String? brokerAddress,
    int? brokerPort,
    String? pairingToken,
    String? ownerUserId,
    String? homeId,
    String? householdId,
    Map<String, dynamic>? displayConfig,
    DateTime? pairedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Panel(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      displayName: displayName ?? this.displayName,
      brokerAddress: brokerAddress ?? this.brokerAddress,
      brokerPort: brokerPort ?? this.brokerPort,
      pairingToken: pairingToken ?? this.pairingToken,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      homeId: homeId ?? this.homeId,
      householdId: householdId ?? this.householdId,
      displayConfig: displayConfig ?? this.displayConfig,
      pairedAt: pairedAt ?? this.pairedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// List of device IDs configured for this panel
  List<String> get configuredDeviceIds {
    final config = displayConfig;
    if (config == null) return [];
    final devices = config['devices'];
    if (devices is List) return devices.cast<Map<String, dynamic>>().map((d) => d['id'] as String).toList();
    return [];
  }

  /// List of scene IDs configured for this panel
  List<String> get configuredSceneIds {
    final config = displayConfig;
    if (config == null) return [];
    final scenes = config['scenes'];
    if (scenes is List) return scenes.cast<Map<String, dynamic>>().map((s) => s['id'] as String).toList();
    return [];
  }
}

/// Represents a device entry in the panel display config
class PanelDeviceConfig {
  final String id;
  final String name;
  final String type;
  final String topic;
  final String? room;

  const PanelDeviceConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.topic,
    this.room,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'topic': topic,
    if (room != null) 'room': room,
  };

  factory PanelDeviceConfig.fromJson(Map<String, dynamic> json) => PanelDeviceConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    topic: json['topic'] as String,
    room: json['room'] as String?,
  );
}

/// Represents a scene entry in the panel display config
class PanelSceneConfig {
  final String id;
  final String name;
  final String? icon;

  const PanelSceneConfig({
    required this.id,
    required this.name,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (icon != null) 'icon': icon,
  };

  factory PanelSceneConfig.fromJson(Map<String, dynamic> json) => PanelSceneConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String?,
  );
}
