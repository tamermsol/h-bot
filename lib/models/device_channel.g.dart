// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceChannel _$DeviceChannelFromJson(Map<String, dynamic> json) =>
    DeviceChannel(
      deviceId: json['device_id'] as String,
      channelNo: (json['channel_no'] as num).toInt(),
      label: json['label'] as String,
      labelIsCustom: json['label_is_custom'] as bool,
      channelType: json['channel_type'] as String? ?? 'light',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DeviceChannelToJson(DeviceChannel instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'channel_no': instance.channelNo,
      'label': instance.label,
      'label_is_custom': instance.labelIsCustom,
      'channel_type': instance.channelType,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

DeviceChannelRequest _$DeviceChannelRequestFromJson(
  Map<String, dynamic> json,
) => DeviceChannelRequest(
  deviceId: json['device_id'] as String,
  channelNo: (json['channel_no'] as num).toInt(),
  label: json['label'] as String,
);

Map<String, dynamic> _$DeviceChannelRequestToJson(
  DeviceChannelRequest instance,
) => <String, dynamic>{
  'device_id': instance.deviceId,
  'channel_no': instance.channelNo,
  'label': instance.label,
};

DeviceWithChannels _$DeviceWithChannelsFromJson(Map<String, dynamic> json) =>
    DeviceWithChannels(
      id: json['id'] as String,
      topicBase: json['topic_base'] as String,
      macAddress: json['mac_address'] as String?,
      ownerUserId: json['owner_user_id'] as String,
      displayName: json['display_name'] as String,
      nameIsCustom: json['name_is_custom'] as bool,
      channels: (json['channels'] as num?)?.toInt(),
      homeId: json['home_id'] as String?,
      roomId: json['room_id'] as String?,
      deviceType: json['device_type'] as String,
      matterType: json['matter_type'] as String?,
      metaJson: json['meta_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      channelLabels: json['channel_labels'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$DeviceWithChannelsToJson(DeviceWithChannels instance) =>
    <String, dynamic>{
      'id': instance.id,
      'topic_base': instance.topicBase,
      'mac_address': instance.macAddress,
      'owner_user_id': instance.ownerUserId,
      'display_name': instance.displayName,
      'name_is_custom': instance.nameIsCustom,
      'channels': instance.channels,
      'home_id': instance.homeId,
      'room_id': instance.roomId,
      'device_type': instance.deviceType,
      'matter_type': instance.matterType,
      'meta_json': instance.metaJson,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
      'channel_labels': instance.channelLabels,
    };
