// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_trigger.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SceneTrigger _$SceneTriggerFromJson(Map<String, dynamic> json) => SceneTrigger(
  id: json['id'] as String,
  sceneId: json['scene_id'] as String,
  kind: $enumDecode(_$TriggerKindEnumMap, json['kind']),
  configJson: json['config_json'] as Map<String, dynamic>,
  isEnabled: json['is_enabled'] as bool,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$SceneTriggerToJson(SceneTrigger instance) =>
    <String, dynamic>{
      'id': instance.id,
      'scene_id': instance.sceneId,
      'kind': instance.kind,
      'config_json': instance.configJson,
      'is_enabled': instance.isEnabled,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$TriggerKindEnumMap = {
  TriggerKind.manual: 'manual',
  TriggerKind.schedule: 'schedule',
  TriggerKind.event: 'event',
  TriggerKind.state: 'state',
  TriggerKind.geo: 'geo',
};
