// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_step.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SceneStep _$SceneStepFromJson(Map<String, dynamic> json) => SceneStep(
      id: json['id'] as String,
      sceneId: json['scene_id'] as String,
      stepOrder: (json['step_order'] as num).toInt(),
      actionJson: json['action_json'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SceneStepToJson(SceneStep instance) => <String, dynamic>{
      'id': instance.id,
      'scene_id': instance.sceneId,
      'step_order': instance.stepOrder,
      'action_json': instance.actionJson,
      'created_at': instance.createdAt.toIso8601String(),
    };
