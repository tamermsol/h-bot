// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ha_connection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HaConnection _$HaConnectionFromJson(Map<String, dynamic> json) => HaConnection(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      instanceName: json['instance_name'] as String? ?? 'Home',
      baseUrl: json['base_url'] as String,
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenExpiresAt: json['token_expires_at'] == null
          ? null
          : DateTime.parse(json['token_expires_at'] as String),
      haVersion: json['ha_version'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      lastSyncAt: json['last_sync_at'] == null
          ? null
          : DateTime.parse(json['last_sync_at'] as String),
      lastError: json['last_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$HaConnectionToJson(HaConnection instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'instance_name': instance.instanceName,
      'base_url': instance.baseUrl,
      'access_token': instance.accessToken,
      'refresh_token': instance.refreshToken,
      'token_expires_at': instance.tokenExpiresAt?.toIso8601String(),
      'ha_version': instance.haVersion,
      'is_active': instance.isActive,
      'last_sync_at': instance.lastSyncAt?.toIso8601String(),
      'last_error': instance.lastError,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
