import 'package:json_annotation/json_annotation.dart';

part 'scene_step.g.dart';

@JsonSerializable()
class SceneStep {
  final String id;
  @JsonKey(name: 'scene_id')
  final String sceneId;
  @JsonKey(name: 'step_order')
  final int stepOrder;
  @JsonKey(name: 'action_json')
  final Map<String, dynamic> actionJson;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const SceneStep({
    required this.id,
    required this.sceneId,
    required this.stepOrder,
    required this.actionJson,
    required this.createdAt,
  });

  factory SceneStep.fromJson(Map<String, dynamic> json) => _$SceneStepFromJson(json);
  Map<String, dynamic> toJson() => _$SceneStepToJson(this);

  SceneStep copyWith({
    String? id,
    String? sceneId,
    int? stepOrder,
    Map<String, dynamic>? actionJson,
    DateTime? createdAt,
  }) {
    return SceneStep(
      id: id ?? this.id,
      sceneId: sceneId ?? this.sceneId,
      stepOrder: stepOrder ?? this.stepOrder,
      actionJson: actionJson ?? this.actionJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
