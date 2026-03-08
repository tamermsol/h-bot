import 'package:json_annotation/json_annotation.dart';

part 'home.g.dart';

@JsonSerializable()
class Home {
  final String id;
  @JsonKey(name: 'owner_id')
  final String ownerId;
  final String name;
  @JsonKey(name: 'background_image_url')
  final String? backgroundImageUrl;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Home({
    required this.id,
    required this.ownerId,
    required this.name,
    this.backgroundImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Home.fromJson(Map<String, dynamic> json) => _$HomeFromJson(json);
  Map<String, dynamic> toJson() => _$HomeToJson(this);

  Home copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? backgroundImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Home(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
