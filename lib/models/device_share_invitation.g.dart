// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_share_invitation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceShareInvitation _$DeviceShareInvitationFromJson(
        Map<String, dynamic> json) =>
    DeviceShareInvitation(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      ownerId: json['owner_id'] as String,
      invitationCode: json['invitation_code'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$DeviceShareInvitationToJson(
        DeviceShareInvitation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'owner_id': instance.ownerId,
      'invitation_code': instance.invitationCode,
      'expires_at': instance.expiresAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
