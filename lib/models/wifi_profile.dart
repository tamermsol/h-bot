import 'package:json_annotation/json_annotation.dart';

part 'wifi_profile.g.dart';

/// User's Wi-Fi profile for device provisioning
@JsonSerializable()
class WiFiProfile {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final String ssid;
  final String password;
  @JsonKey(name: 'is_default')
  final bool isDefault;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const WiFiProfile({
    required this.id,
    required this.userId,
    required this.ssid,
    required this.password,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WiFiProfile.fromJson(Map<String, dynamic> json) =>
      _$WiFiProfileFromJson(json);
  Map<String, dynamic> toJson() => _$WiFiProfileToJson(this);

  WiFiProfile copyWith({
    String? id,
    String? userId,
    String? ssid,
    String? password,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WiFiProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WiFiProfile &&
        other.id == id &&
        other.userId == userId &&
        other.ssid == ssid &&
        other.password == password &&
        other.isDefault == isDefault &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      ssid,
      password,
      isDefault,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'WiFiProfile(id: $id, userId: $userId, ssid: $ssid, isDefault: $isDefault)';
  }
}

/// Request to create or update a Wi-Fi profile
@JsonSerializable()
class WiFiProfileRequest {
  final String ssid;
  final String password;
  final bool isDefault;

  const WiFiProfileRequest({
    required this.ssid,
    required this.password,
    this.isDefault = false,
  });

  factory WiFiProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$WiFiProfileRequestFromJson(json);
  Map<String, dynamic> toJson() => _$WiFiProfileRequestToJson(this);
}
