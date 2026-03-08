// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Scene _$SceneFromJson(Map<String, dynamic> json) => Scene(
      id: json['id'] as String,
      homeId: json['home_id'] as String,
      name: json['name'] as String,
      isEnabled: json['is_enabled'] as bool,
      iconCode: (json['icon_code'] as num?)?.toInt(),
      colorValue: (json['color_value'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SceneToJson(Scene instance) => <String, dynamic>{
      'id': instance.id,
      'home_id': instance.homeId,
      'name': instance.name,
      'is_enabled': instance.isEnabled,
      'icon_code': instance.iconCode,
      'color_value': instance.colorValue,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };
