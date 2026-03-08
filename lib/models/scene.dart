import 'package:json_annotation/json_annotation.dart';

part 'scene.g.dart';

@JsonSerializable()
class Scene {
  final String id;
  @JsonKey(name: 'home_id')
  final String homeId;
  final String name;
  @JsonKey(name: 'is_enabled')
  final bool isEnabled;
  @JsonKey(name: 'icon_code')
  final int? iconCode;
  @JsonKey(name: 'color_value')
  final int? colorValue;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Scene({
    required this.id,
    required this.homeId,
    required this.name,
    required this.isEnabled,
    this.iconCode,
    this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Scene.fromJson(Map<String, dynamic> json) => _$SceneFromJson(json);
  Map<String, dynamic> toJson() => _$SceneToJson(this);

  Scene copyWith({
    String? id,
    String? homeId,
    String? name,
    bool? isEnabled,
    int? iconCode,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Scene(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      isEnabled: isEnabled ?? this.isEnabled,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
