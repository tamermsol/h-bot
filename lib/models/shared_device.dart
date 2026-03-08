import 'package:json_annotation/json_annotation.dart';

part 'shared_device.g.dart';

enum PermissionLevel { view, control }

@JsonSerializable()
class SharedDevice {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  @JsonKey(name: 'shared_with_id')
  final String sharedWithId;
  @JsonKey(name: 'permission_level')
  final PermissionLevel permissionLevel;
  @JsonKey(name: 'shared_at')
  final DateTime sharedAt;

  // Additional fields from joins
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? deviceName;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? deviceType;
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? ownerEmail;

  SharedDevice({
    required this.id,
    required this.deviceId,
    required this.ownerId,
    required this.sharedWithId,
    required this.permissionLevel,
    required this.sharedAt,
    this.deviceName,
    this.deviceType,
    this.ownerEmail,
  });

  factory SharedDevice.fromJson(Map<String, dynamic> json) =>
      _$SharedDeviceFromJson(json);
  Map<String, dynamic> toJson() => _$SharedDeviceToJson(this);

  bool get canControl => permissionLevel == PermissionLevel.control;
}
