// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_device.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SharedDevice _$SharedDeviceFromJson(Map<String, dynamic> json) => SharedDevice(
  id: json['id'] as String,
  deviceId: json['device_id'] as String,
  ownerId: json['owner_id'] as String,
  sharedWithId: json['shared_with_id'] as String,
  permissionLevel: $enumDecode(
    _$PermissionLevelEnumMap,
    json['permission_level'],
  ),
  sharedAt: DateTime.parse(json['shared_at'] as String),
);

Map<String, dynamic> _$SharedDeviceToJson(SharedDevice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'owner_id': instance.ownerId,
      'shared_with_id': instance.sharedWithId,
      'permission_level': _$PermissionLevelEnumMap[instance.permissionLevel]!,
      'shared_at': instance.sharedAt.toIso8601String(),
    };

const _$PermissionLevelEnumMap = {
  PermissionLevel.view: 'view',
  PermissionLevel.control: 'control',
};
