import 'package:json_annotation/json_annotation.dart';

part 'ha_entity.g.dart';

/// Supported Home Assistant entity domains
enum HaDomain {
  light,
  @JsonValue('switch')
  switchDomain,
  climate,
  cover,
  sensor,
  @JsonValue('binary_sensor')
  binarySensor,
  fan,
  lock,
  @JsonValue('media_player')
  mediaPlayer,
  camera,
  scene,
  button,
  number,
  @JsonValue('input_boolean')
  inputBoolean,
  @JsonValue('input_number')
  inputNumber,
  other;

  static HaDomain fromString(String domain) {
    switch (domain) {
      case 'light':
        return HaDomain.light;
      case 'switch':
        return HaDomain.switchDomain;
      case 'climate':
        return HaDomain.climate;
      case 'cover':
        return HaDomain.cover;
      case 'sensor':
        return HaDomain.sensor;
      case 'binary_sensor':
        return HaDomain.binarySensor;
      case 'fan':
        return HaDomain.fan;
      case 'lock':
        return HaDomain.lock;
      case 'media_player':
        return HaDomain.mediaPlayer;
      case 'camera':
        return HaDomain.camera;
      case 'scene':
        return HaDomain.scene;
      case 'button':
        return HaDomain.button;
      case 'number':
        return HaDomain.number;
      case 'input_boolean':
        return HaDomain.inputBoolean;
      case 'input_number':
        return HaDomain.inputNumber;
      default:
        return HaDomain.other;
    }
  }

  /// Whether this domain represents a controllable entity
  bool get isControllable {
    switch (this) {
      case HaDomain.light:
      case HaDomain.switchDomain:
      case HaDomain.climate:
      case HaDomain.cover:
      case HaDomain.fan:
      case HaDomain.lock:
      case HaDomain.mediaPlayer:
      case HaDomain.scene:
      case HaDomain.button:
      case HaDomain.number:
      case HaDomain.inputBoolean:
      case HaDomain.inputNumber:
        return true;
      case HaDomain.sensor:
      case HaDomain.binarySensor:
      case HaDomain.camera:
      case HaDomain.other:
        return false;
    }
  }

  /// Display-friendly name
  String get displayName {
    switch (this) {
      case HaDomain.light:
        return 'Light';
      case HaDomain.switchDomain:
        return 'Switch';
      case HaDomain.climate:
        return 'Climate';
      case HaDomain.cover:
        return 'Cover';
      case HaDomain.sensor:
        return 'Sensor';
      case HaDomain.binarySensor:
        return 'Binary Sensor';
      case HaDomain.fan:
        return 'Fan';
      case HaDomain.lock:
        return 'Lock';
      case HaDomain.mediaPlayer:
        return 'Media Player';
      case HaDomain.camera:
        return 'Camera';
      case HaDomain.scene:
        return 'Scene';
      case HaDomain.button:
        return 'Button';
      case HaDomain.number:
        return 'Number';
      case HaDomain.inputBoolean:
        return 'Toggle';
      case HaDomain.inputNumber:
        return 'Number Input';
      case HaDomain.other:
        return 'Other';
    }
  }
}

/// A Home Assistant entity imported into H-Bot
@JsonSerializable()
class HaEntity {
  final String id;
  @JsonKey(name: 'connection_id')
  final String connectionId;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'entity_id')
  final String entityId;
  final String domain;
  @JsonKey(name: 'friendly_name')
  final String? friendlyName;
  @JsonKey(name: 'ha_device_id')
  final String? haDeviceId;
  @JsonKey(name: 'ha_area_id')
  final String? haAreaId;
  @JsonKey(name: 'ha_area_name')
  final String? haAreaName;
  @JsonKey(name: 'home_id')
  final String? homeId;
  @JsonKey(name: 'room_id')
  final String? roomId;
  @JsonKey(name: 'is_visible')
  final bool isVisible;
  final String? icon;
  @JsonKey(name: 'device_class')
  final String? deviceClass;
  @JsonKey(name: 'supported_features')
  final int supportedFeatures;
  @JsonKey(name: 'state_json')
  final Map<String, dynamic>? stateJson;
  @JsonKey(name: 'last_state_at')
  final DateTime? lastStateAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const HaEntity({
    required this.id,
    required this.connectionId,
    required this.userId,
    required this.entityId,
    required this.domain,
    this.friendlyName,
    this.haDeviceId,
    this.haAreaId,
    this.haAreaName,
    this.homeId,
    this.roomId,
    this.isVisible = true,
    this.icon,
    this.deviceClass,
    this.supportedFeatures = 0,
    this.stateJson,
    this.lastStateAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HaEntity.fromJson(Map<String, dynamic> json) =>
      _$HaEntityFromJson(json);
  Map<String, dynamic> toJson() => _$HaEntityToJson(this);

  /// Get the parsed domain enum
  HaDomain get domainEnum => HaDomain.fromString(domain);

  /// Get the display name (friendly_name or entity_id)
  String get displayName =>
      friendlyName ?? entityId.split('.').last.replaceAll('_', ' ');

  /// Get the current state string from stateJson
  String? get currentState => stateJson?['state'] as String?;

  /// Get attributes from stateJson
  Map<String, dynamic>? get attributes =>
      stateJson?['attributes'] as Map<String, dynamic>?;

  /// Whether the entity is currently on/active
  bool get isOn {
    final state = currentState;
    return state == 'on' || state == 'home' || state == 'playing';
  }

  /// Get brightness (0-255) for lights
  int? get brightness => attributes?['brightness'] as int?;

  /// Get color temperature in Kelvin for lights
  int? get colorTempKelvin => attributes?['color_temp_kelvin'] as int?;

  /// Get current temperature for climate entities
  double? get currentTemperature {
    final val = attributes?['current_temperature'];
    if (val is num) return val.toDouble();
    return null;
  }

  /// Get target temperature for climate entities
  double? get targetTemperature {
    final val = attributes?['temperature'];
    if (val is num) return val.toDouble();
    return null;
  }

  /// Get cover position (0-100)
  int? get coverPosition => attributes?['current_position'] as int?;

  /// Get unit of measurement for sensors
  String? get unitOfMeasurement =>
      attributes?['unit_of_measurement'] as String?;

  HaEntity copyWith({
    String? id,
    String? connectionId,
    String? userId,
    String? entityId,
    String? domain,
    String? friendlyName,
    String? haDeviceId,
    String? haAreaId,
    String? haAreaName,
    String? homeId,
    String? roomId,
    bool? isVisible,
    String? icon,
    String? deviceClass,
    int? supportedFeatures,
    Map<String, dynamic>? stateJson,
    DateTime? lastStateAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HaEntity(
      id: id ?? this.id,
      connectionId: connectionId ?? this.connectionId,
      userId: userId ?? this.userId,
      entityId: entityId ?? this.entityId,
      domain: domain ?? this.domain,
      friendlyName: friendlyName ?? this.friendlyName,
      haDeviceId: haDeviceId ?? this.haDeviceId,
      haAreaId: haAreaId ?? this.haAreaId,
      haAreaName: haAreaName ?? this.haAreaName,
      homeId: homeId ?? this.homeId,
      roomId: roomId ?? this.roomId,
      isVisible: isVisible ?? this.isVisible,
      icon: icon ?? this.icon,
      deviceClass: deviceClass ?? this.deviceClass,
      supportedFeatures: supportedFeatures ?? this.supportedFeatures,
      stateJson: stateJson ?? this.stateJson,
      lastStateAt: lastStateAt ?? this.lastStateAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Lightweight HA entity state from WebSocket (not persisted)
class HaEntityState {
  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime lastChanged;

  const HaEntityState({
    required this.entityId,
    required this.state,
    required this.attributes,
    required this.lastChanged,
  });

  factory HaEntityState.fromWsEvent(Map<String, dynamic> data) {
    final newState = data['new_state'] as Map<String, dynamic>? ?? data;
    return HaEntityState(
      entityId: (newState['entity_id'] ?? data['entity_id'] ?? '') as String,
      state: (newState['state'] ?? 'unknown') as String,
      attributes:
          (newState['attributes'] as Map<String, dynamic>?) ?? const {},
      lastChanged: DateTime.tryParse(
              (newState['last_changed'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  bool get isOn => state == 'on' || state == 'home' || state == 'playing';
  int? get brightness => attributes['brightness'] as int?;
  int? get colorTempKelvin => attributes['color_temp_kelvin'] as int?;
  String? get unitOfMeasurement =>
      attributes['unit_of_measurement'] as String?;
}
