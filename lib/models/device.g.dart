// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
      id: json['id'] as String,
      homeId: json['home_id'] as String?,
      roomId: json['room_id'] as String?,
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      nameIsCustom: json['name_is_custom'] as bool?,
      deviceType: $enumDecode(_$DeviceTypeEnumMap, json['device_type']),
      channels: (json['channels'] as num?)?.toInt(),
      channelCount: (json['channel_count'] as num?)?.toInt(),
      online: json['online'] as bool?,
      lastSeenAt: json['last_seen_at'] == null
          ? null
          : DateTime.parse(json['last_seen_at'] as String),
      tasmotaTopicBase: json['tasmota_topic_base'] as String?,
      topicBase: json['topic_base'] as String?,
      macAddress: json['mac_address'] as String?,
      ownerUserId: json['owner_user_id'] as String?,
      matterType: json['matter_type'] as String?,
      metaJson: json['meta_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DeviceToJson(Device instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'home_id': instance.homeId,
    'room_id': instance.roomId,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('name', instance.name);
  writeNotNull('display_name', instance.displayName);
  writeNotNull('name_is_custom', instance.nameIsCustom);
  val['device_type'] = _$DeviceTypeEnumMap[instance.deviceType]!;
  val['channels'] = instance.channels;
  writeNotNull('channel_count', instance.channelCount);
  writeNotNull('online', instance.online);
  writeNotNull('last_seen_at', instance.lastSeenAt?.toIso8601String());
  writeNotNull('tasmota_topic_base', instance.tasmotaTopicBase);
  writeNotNull('topic_base', instance.topicBase);
  writeNotNull('mac_address', instance.macAddress);
  writeNotNull('owner_user_id', instance.ownerUserId);
  val['matter_type'] = instance.matterType;
  val['meta_json'] = instance.metaJson;
  val['created_at'] = instance.createdAt.toIso8601String();
  val['updated_at'] = instance.updatedAt.toIso8601String();
  return val;
}

const _$DeviceTypeEnumMap = {
  DeviceType.relay: 'relay',
  DeviceType.dimmer: 'dimmer',
  DeviceType.shutter: 'shutter',
  DeviceType.sensor: 'sensor',
  DeviceType.other: 'other',
};
