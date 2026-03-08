import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@JsonSerializable()
class Profile {
  final String id;
  @JsonKey(name: 'full_name')
  final String? fullName;
  @JsonKey(name: 'phone_number')
  final String? phoneNumber;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.fullName,
    this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  Profile copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validates phone number format (E.164-ish: ^\+?[1-9]\d{1,14}$)
  static bool isValidPhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return true; // nullable
    return RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(phoneNumber);
  }

  /// Validates full name (non-empty when provided)
  static bool isValidFullName(String? fullName) {
    if (fullName == null) return true; // nullable
    return fullName.trim().isNotEmpty;
  }

  /// Creates a new profile with current timestamp
  static Profile create({
    required String id,
    String? fullName,
    String? phoneNumber,
  }) {
    final now = DateTime.now();
    return Profile(
      id: id,
      fullName: fullName?.trim(),
      phoneNumber: phoneNumber?.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }
}
