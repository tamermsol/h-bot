// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scene_run.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SceneRun _$SceneRunFromJson(Map<String, dynamic> json) => SceneRun(
      id: json['id'] as String,
      sceneId: json['scene_id'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: json['finished_at'] == null
          ? null
          : DateTime.parse(json['finished_at'] as String),
      status: $enumDecode(_$SceneRunStatusEnumMap, json['status']),
      logsJson: json['logs_json'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$SceneRunToJson(SceneRun instance) => <String, dynamic>{
      'id': instance.id,
      'scene_id': instance.sceneId,
      'started_at': instance.startedAt.toIso8601String(),
      'finished_at': instance.finishedAt?.toIso8601String(),
      'status': instance.status,
      'logs_json': instance.logsJson,
    };

const _$SceneRunStatusEnumMap = {
  SceneRunStatus.running: 'running',
  SceneRunStatus.success: 'success',
  SceneRunStatus.failed: 'failed',
  SceneRunStatus.skipped: 'skipped',
};
