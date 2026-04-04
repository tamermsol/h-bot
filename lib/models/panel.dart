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

/// Represents a device entry in the panel display config.
/// Uses 'label' for display name (agreed with smarty), 'visible' for show/hide.
class PanelDeviceConfig {
  final String id;
  final String label;
  final String icon; // light, fan, switch, outlet, ac, curtain
  final String type;
  final String topic;
  final bool visible;
  final String? room;
  final int? relayIndex; // for panel built-in relays

  const PanelDeviceConfig({
    required this.id,
    required this.label,
    this.icon = 'switch',
    required this.type,
    required this.topic,
    this.visible = true,
    this.room,
    this.relayIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': icon,
    'type': type,
    'topic': topic,
    'visible': visible,
    if (room != null) 'room': room,
    if (relayIndex != null) 'relay_index': relayIndex,
  };

  factory PanelDeviceConfig.fromJson(Map<String, dynamic> json) => PanelDeviceConfig(
    id: json['id'] as String,
    label: (json['label'] ?? json['name'] ?? '') as String,
    icon: (json['icon'] ?? 'switch') as String,
    type: (json['type'] ?? 'relay') as String,
    topic: (json['topic'] ?? '') as String,
    visible: json['visible'] as bool? ?? true,
    room: json['room'] as String?,
    relayIndex: json['relay_index'] as int?,
  );

  PanelDeviceConfig copyWith({bool? visible, String? label}) => PanelDeviceConfig(
    id: id,
    label: label ?? this.label,
    icon: icon,
    type: type,
    topic: topic,
    visible: visible ?? this.visible,
    room: room,
    relayIndex: relayIndex,
  );
}

/// Represents a scene entry in the panel display config
class PanelSceneConfig {
  final String id;
  final String label;
  final String? icon;

  const PanelSceneConfig({
    required this.id,
    required this.label,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    if (icon != null) 'icon': icon,
  };

  factory PanelSceneConfig.fromJson(Map<String, dynamic> json) => PanelSceneConfig(
    id: json['id'] as String,
    label: (json['label'] ?? json['name'] ?? '') as String,
    icon: json['icon'] as String?,
  );
}

/// Maps device type to panel icon name (agreed icon set with smarty)
String deviceTypeToIcon(String type) {
  switch (type) {
    case 'relay': return 'light';
    case 'dimmer': return 'light';
    case 'shutter': return 'curtain';
    case 'sensor': return 'switch';
    default: return 'switch';
  }
}
