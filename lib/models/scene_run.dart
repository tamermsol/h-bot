import 'package:json_annotation/json_annotation.dart';

part 'scene_run.g.dart';

enum SceneRunStatus {
  running,
  success,
  failed,
  skipped;

  String toJson() => name;
  static SceneRunStatus fromJson(String json) => SceneRunStatus.values.byName(json);
}

@JsonSerializable()
class SceneRun {
  final String id;
  @JsonKey(name: 'scene_id')
  final String? sceneId;
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @JsonKey(name: 'finished_at')
  final DateTime? finishedAt;
  final SceneRunStatus status;
  @JsonKey(name: 'logs_json')
  final Map<String, dynamic>? logsJson;

  const SceneRun({
    required this.id,
    this.sceneId,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    this.logsJson,
  });

  factory SceneRun.fromJson(Map<String, dynamic> json) => _$SceneRunFromJson(json);
  Map<String, dynamic> toJson() => _$SceneRunToJson(this);

  SceneRun copyWith({
    String? id,
    String? sceneId,
    DateTime? startedAt,
    DateTime? finishedAt,
    SceneRunStatus? status,
    Map<String, dynamic>? logsJson,
  }) {
    return SceneRun(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      status: status ?? this.status,
      logsJson: logsJson ?? this.logsJson,
    );
  }
}
