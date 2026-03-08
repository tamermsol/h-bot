// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Room _$RoomFromJson(Map<String, dynamic> json) => Room(
  id: json['id'] as String,
  homeId: json['home_id'] as String,
  name: json['name'] as String,
  sortOrder: (json['sort_order'] as num).toInt(),
  backgroundImageUrl: json['background_image_url'] as String?,
  iconName: json['icon_name'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$RoomToJson(Room instance) => <String, dynamic>{
  'id': instance.id,
  'home_id': instance.homeId,
  'name': instance.name,
  'sort_order': instance.sortOrder,
  'background_image_url': instance.backgroundImageUrl,
  'icon_name': instance.iconName,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};
