// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ha_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HaEntity _$HaEntityFromJson(Map<String, dynamic> json) => HaEntity(
      id: json['id'] as String,
      connectionId: json['connection_id'] as String,
      userId: json['user_id'] as String,
      entityId: json['entity_id'] as String,
      domain: json['domain'] as String,
      friendlyName: json['friendly_name'] as String?,
      haDeviceId: json['ha_device_id'] as String?,
      haAreaId: json['ha_area_id'] as String?,
      haAreaName: json['ha_area_name'] as String?,
      homeId: json['home_id'] as String?,
      roomId: json['room_id'] as String?,
      isVisible: json['is_visible'] as bool? ?? true,
      icon: json['icon'] as String?,
      deviceClass: json['device_class'] as String?,
      supportedFeatures: (json['supported_features'] as num?)?.toInt() ?? 0,
      stateJson: json['state_json'] as Map<String, dynamic>?,
      lastStateAt: json['last_state_at'] == null
          ? null
          : DateTime.parse(json['last_state_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$HaEntityToJson(HaEntity instance) => <String, dynamic>{
      'id': instance.id,
      'connection_id': instance.connectionId,
      'user_id': instance.userId,
      'entity_id': instance.entityId,
      'domain': instance.domain,
      'friendly_name': instance.friendlyName,
      'ha_device_id': instance.haDeviceId,
      'ha_area_id': instance.haAreaId,
      'ha_area_name': instance.haAreaName,
      'home_id': instance.homeId,
      'room_id': instance.roomId,
      'is_visible': instance.isVisible,
      'icon': instance.icon,
      'device_class': instance.deviceClass,
      'supported_features': instance.supportedFeatures,
      'state_json': instance.stateJson,
      'last_state_at': instance.lastStateAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
