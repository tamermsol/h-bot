import 'package:json_annotation/json_annotation.dart';

part 'ha_connection.g.dart';

@JsonSerializable()
class HaConnection {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'instance_name')
  final String instanceName;
  @JsonKey(name: 'base_url')
  final String baseUrl;
  @JsonKey(name: 'access_token')
  final String? accessToken;
  @JsonKey(name: 'refresh_token')
  final String? refreshToken;
  @JsonKey(name: 'token_expires_at')
  final DateTime? tokenExpiresAt;
  @JsonKey(name: 'ha_version')
  final String? haVersion;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'last_sync_at')
  final DateTime? lastSyncAt;
  @JsonKey(name: 'last_error')
  final String? lastError;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const HaConnection({
    required this.id,
    required this.userId,
    this.instanceName = 'Home',
    required this.baseUrl,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiresAt,
    this.haVersion,
    this.isActive = true,
    this.lastSyncAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HaConnection.fromJson(Map<String, dynamic> json) =>
      _$HaConnectionFromJson(json);
  Map<String, dynamic> toJson() => _$HaConnectionToJson(this);

  /// Get the WebSocket URL from the base URL
  String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}/api/websocket';
  }

  /// Get the REST API base URL
  String get apiUrl => '$baseUrl/api';

  HaConnection copyWith({
    String? id,
    String? userId,
    String? instanceName,
    String? baseUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiresAt,
    String? haVersion,
    bool? isActive,
    DateTime? lastSyncAt,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HaConnection(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      instanceName: instanceName ?? this.instanceName,
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
      haVersion: haVersion ?? this.haVersion,
      isActive: isActive ?? this.isActive,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
