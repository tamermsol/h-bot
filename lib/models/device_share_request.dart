import 'package:json_annotation/json_annotation.dart';

part 'device_share_request.g.dart';

enum ShareRequestStatus { pending, approved, rejected }

@JsonSerializable()
class DeviceShareRequest {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @JsonKey(name: 'requester_id')
  final String requesterId;
  @JsonKey(name: 'requester_email')
  final String requesterEmail;
  @JsonKey(name: 'requester_name')
  final String? requesterName;
  final ShareRequestStatus status;
  @JsonKey(name: 'requested_at')
  final DateTime requestedAt;
  @JsonKey(name: 'responded_at')
  final DateTime? respondedAt;

  // Additional fields from joins
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? deviceName;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? deviceType;

  DeviceShareRequest({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.requesterId,
    required this.requesterEmail,
    this.requesterName,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.deviceName,
    this.deviceType,
  });

  factory DeviceShareRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceShareRequestFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceShareRequestToJson(this);
}
