// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_share_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceShareRequest _$DeviceShareRequestFromJson(Map<String, dynamic> json) =>
    DeviceShareRequest(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      ownerId: json['owner_id'] as String,
      requesterId: json['requester_id'] as String,
      requesterEmail: json['requester_email'] as String,
      requesterName: json['requester_name'] as String?,
      status: $enumDecode(_$ShareRequestStatusEnumMap, json['status']),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      respondedAt: json['responded_at'] == null
          ? null
          : DateTime.parse(json['responded_at'] as String),
    );

Map<String, dynamic> _$DeviceShareRequestToJson(DeviceShareRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'owner_id': instance.ownerId,
      'requester_id': instance.requesterId,
      'requester_email': instance.requesterEmail,
      'requester_name': instance.requesterName,
      'status': _$ShareRequestStatusEnumMap[instance.status]!,
      'requested_at': instance.requestedAt.toIso8601String(),
      'responded_at': instance.respondedAt?.toIso8601String(),
    };

const _$ShareRequestStatusEnumMap = {
  ShareRequestStatus.pending: 'pending',
  ShareRequestStatus.approved: 'approved',
  ShareRequestStatus.rejected: 'rejected',
};
