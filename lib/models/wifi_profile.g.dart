// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wifi_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WiFiProfile _$WiFiProfileFromJson(Map<String, dynamic> json) => WiFiProfile(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  ssid: json['ssid'] as String,
  password: json['password'] as String,
  isDefault: json['is_default'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$WiFiProfileToJson(WiFiProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'ssid': instance.ssid,
      'password': instance.password,
      'is_default': instance.isDefault,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

WiFiProfileRequest _$WiFiProfileRequestFromJson(Map<String, dynamic> json) =>
    WiFiProfileRequest(
      ssid: json['ssid'] as String,
      password: json['password'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$WiFiProfileRequestToJson(WiFiProfileRequest instance) =>
    <String, dynamic>{
      'ssid': instance.ssid,
      'password': instance.password,
      'isDefault': instance.isDefault,
    };
