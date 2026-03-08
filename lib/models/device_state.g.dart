// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceState _$DeviceStateFromJson(Map<String, dynamic> json) => DeviceState(
  deviceId: json['device_id'] as String,
  reportedAt: DateTime.parse(json['reported_at'] as String),
  online: json['online'] as bool,
  stateJson: json['state_json'] as Map<String, dynamic>,
);

Map<String, dynamic> _$DeviceStateToJson(DeviceState instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'reported_at': instance.reportedAt.toIso8601String(),
      'online': instance.online,
      'state_json': instance.stateJson,
    };

DeviceWithState _$DeviceWithStateFromJson(Map<String, dynamic> json) =>
    DeviceWithState(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      roomId: json['room_id'] as String?,
      name: json['name'] as String,
      deviceType: json['device_type'] as String,
      channels: (json['channels'] as num).toInt(),
      tasmotaTopicBase: json['tasmota_topic_base'] as String?,
      matterType: json['matter_type'] as String?,
      metaJson: json['meta_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reportedAt: json['reported_at'] == null
          ? null
          : DateTime.parse(json['reported_at'] as String),
      online: json['online'] as bool?,
      stateJson: json['state_json'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeviceWithStateToJson(DeviceWithState instance) =>
    <String, dynamic>{
      'id': instance.id,
      'home_id': instance.homeId,
      'room_id': instance.roomId,
      'name': instance.name,
      'device_type': instance.deviceType,
      'channels': instance.channels,
      'tasmota_topic_base': instance.tasmotaTopicBase,
      'matter_type': instance.matterType,
      'meta_json': instance.metaJson,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'reported_at': instance.reportedAt?.toIso8601String(),
      'online': instance.online,
      'state_json': instance.stateJson,
    };
