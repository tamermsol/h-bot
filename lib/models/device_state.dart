import 'package:json_annotation/json_annotation.dart';

part 'device_state.g.dart';

@JsonSerializable()
class DeviceState {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'reported_at')
  final DateTime reportedAt;
  final bool online;
  @JsonKey(name: 'state_json')
  final Map<String, dynamic> stateJson;

  const DeviceState({
    required this.deviceId,
    required this.reportedAt,
    required this.online,
    required this.stateJson,
  });

  factory DeviceState.fromJson(Map<String, dynamic> json) => _$DeviceStateFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceStateToJson(this);

  DeviceState copyWith({
    String? deviceId,
    DateTime? reportedAt,
    bool? online,
    Map<String, dynamic>? stateJson,
  }) {
    return DeviceState(
      deviceId: deviceId ?? this.deviceId,
      reportedAt: reportedAt ?? this.reportedAt,
      online: online ?? this.online,
      stateJson: stateJson ?? this.stateJson,
    );
  }
}

/// Combined device with its current state
@JsonSerializable()
class DeviceWithState {
  final String id;
  @JsonKey(name: 'home_id')
  final String homeId;
  @JsonKey(name: 'room_id')
  final String? roomId;
  final String name;
  @JsonKey(name: 'device_type')
  final String deviceType;
  final int channels;
  @JsonKey(name: 'tasmota_topic_base')
  final String? tasmotaTopicBase;
  @JsonKey(name: 'matter_type')
  final String? matterType;
  @JsonKey(name: 'meta_json')
  final Map<String, dynamic>? metaJson;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  // State fields (nullable if no state exists)
  @JsonKey(name: 'reported_at')
  final DateTime? reportedAt;
  final bool? online;
  @JsonKey(name: 'state_json')
  final Map<String, dynamic>? stateJson;

  const DeviceWithState({
    required this.id,
    required this.homeId,
    this.roomId,
    required this.name,
    required this.deviceType,
    required this.channels,
    this.tasmotaTopicBase,
    this.matterType,
    this.metaJson,
    required this.createdAt,
    required this.updatedAt,
    this.reportedAt,
    this.online,
    this.stateJson,
  });

  factory DeviceWithState.fromJson(Map<String, dynamic> json) => _$DeviceWithStateFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceWithStateToJson(this);
}
