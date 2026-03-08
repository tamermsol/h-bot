import 'package:json_annotation/json_annotation.dart';

part 'device_share_invitation.g.dart';

@JsonSerializable()
class DeviceShareInvitation {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @JsonKey(name: 'invitation_code')
  final String invitationCode;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const DeviceShareInvitation({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.invitationCode,
    required this.expiresAt,
    required this.createdAt,
  });

  factory DeviceShareInvitation.fromJson(Map<String, dynamic> json) =>
      _$DeviceShareInvitationFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceShareInvitationToJson(this);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
