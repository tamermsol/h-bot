import 'package:json_annotation/json_annotation.dart';

part 'scene_trigger.g.dart';

enum TriggerKind {
  manual,
  schedule,
  event,
  state,
  geo;

  String toJson() => name;
  static TriggerKind fromJson(String json) => TriggerKind.values.byName(json);
}

@JsonSerializable()
class SceneTrigger {
  final String id;
  @JsonKey(name: 'scene_id')
  final String sceneId;
  final TriggerKind kind;
  @JsonKey(name: 'config_json')
  final Map<String, dynamic> configJson;
  @JsonKey(name: 'is_enabled')
  final bool isEnabled;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const SceneTrigger({
    required this.id,
    required this.sceneId,
    required this.kind,
    required this.configJson,
    required this.isEnabled,
    required this.createdAt,
  });

  factory SceneTrigger.fromJson(Map<String, dynamic> json) => _$SceneTriggerFromJson(json);
  Map<String, dynamic> toJson() => _$SceneTriggerToJson(this);

  SceneTrigger copyWith({
    String? id,
    String? sceneId,
    TriggerKind? kind,
    Map<String, dynamic>? configJson,
    bool? isEnabled,
    DateTime? createdAt,
  }) {
    return SceneTrigger(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      kind: kind ?? this.kind,
      configJson: configJson ?? this.configJson,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
