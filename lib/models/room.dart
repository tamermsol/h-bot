import 'package:json_annotation/json_annotation.dart';

part 'room.g.dart';

@JsonSerializable()
class Room {
  final String id;
  @JsonKey(name: 'home_id')
  final String homeId;
  final String name;
  @JsonKey(name: 'sort_order')
  final int sortOrder;
  @JsonKey(name: 'background_image_url')
  final String? backgroundImageUrl;
  @JsonKey(name: 'icon_name')
  final String? iconName;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Room({
    required this.id,
    required this.homeId,
    required this.name,
    required this.sortOrder,
    this.backgroundImageUrl,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);
  Map<String, dynamic> toJson() => _$RoomToJson(this);

  Room copyWith({
    String? id,
    String? homeId,
    String? name,
    int? sortOrder,
    String? backgroundImageUrl,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
