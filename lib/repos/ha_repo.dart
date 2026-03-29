import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ha_connection.dart';
import '../models/ha_entity.dart';

/// Repository for Home Assistant data in Supabase
class HaRepo {
  final SupabaseClient _db;

  HaRepo(this._db);

  // --- Connections ---

  /// Get the active HA connection for the current user
  Future<HaConnection?> getActiveConnection() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _db
        .from('ha_connections')
        .select()
        .eq('user_id', userId)
        .eq('is_active', true)
        .maybeSingle();

    if (data == null) return null;
    return HaConnection.fromJson(data);
  }

  /// Create or update HA connection
  Future<HaConnection> upsertConnection({
    required String baseUrl,
    required String accessToken,
    String instanceName = 'Home',
    String? haVersion,
  }) async {
    final userId = _db.auth.currentUser!.id;

    final data = await _db.from('ha_connections').upsert(
      {
        'user_id': userId,
        'base_url': baseUrl,
        'access_token': accessToken,
        'instance_name': instanceName,
        'ha_version': haVersion,
        'is_active': true,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id',
    ).select().single();

    return HaConnection.fromJson(data);
  }

  /// Update last sync timestamp
  Future<void> updateLastSync(String connectionId) async {
    await _db.from('ha_connections').update({
      'last_sync_at': DateTime.now().toIso8601String(),
      'last_error': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', connectionId);
  }

  /// Record a connection error
  Future<void> updateConnectionError(
      String connectionId, String error) async {
    await _db.from('ha_connections').update({
      'last_error': error,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', connectionId);
  }

  /// Delete HA connection and all associated entities
  Future<void> deleteConnection(String connectionId) async {
    await _db.from('ha_connections').delete().eq('id', connectionId);
  }

  // --- Entities ---

  /// Get all visible HA entities for the current user
  Future<List<HaEntity>> getEntities({
    String? domain,
    String? homeId,
    String? roomId,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    var query = _db
        .from('ha_entities')
        .select()
        .eq('user_id', userId)
        .eq('is_visible', true);

    if (domain != null) query = query.eq('domain', domain);
    if (homeId != null) query = query.eq('home_id', homeId);
    if (roomId != null) query = query.eq('room_id', roomId);

    final data = await query.order('domain').order('friendly_name');
    return data.map((e) => HaEntity.fromJson(e)).toList();
  }

  /// Get a single HA entity by its HA entity_id
  Future<HaEntity?> getEntityByHaId(
      String connectionId, String entityId) async {
    final data = await _db
        .from('ha_entities')
        .select()
        .eq('connection_id', connectionId)
        .eq('entity_id', entityId)
        .maybeSingle();

    if (data == null) return null;
    return HaEntity.fromJson(data);
  }

  /// Bulk upsert HA entities (used during sync/discovery)
  Future<void> syncEntities(
    String connectionId,
    List<Map<String, dynamic>> entities,
  ) async {
    if (entities.isEmpty) return;

    final userId = _db.auth.currentUser!.id;

    // Upsert in batches of 50
    for (var i = 0; i < entities.length; i += 50) {
      final batch = entities.skip(i).take(50).map((e) => {
            ...e,
            'connection_id': connectionId,
            'user_id': userId,
            'updated_at': DateTime.now().toIso8601String(),
          }).toList();

      await _db.from('ha_entities').upsert(
        batch,
        onConflict: 'connection_id,entity_id',
      );
    }
  }

  /// Update entity state (cached from WebSocket)
  Future<void> updateEntityState(
      String entityId, Map<String, dynamic> stateJson) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;

    await _db
        .from('ha_entities')
        .update({
          'state_json': stateJson,
          'last_state_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('entity_id', entityId);
  }

  /// Update entity visibility
  Future<void> setEntityVisibility(String id, bool visible) async {
    await _db.from('ha_entities').update({
      'is_visible': visible,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Assign entity to a room
  Future<void> assignEntityToRoom(
      String id, String? homeId, String? roomId) async {
    await _db.from('ha_entities').update({
      'home_id': homeId,
      'room_id': roomId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Delete all entities for a connection
  Future<void> deleteEntitiesForConnection(String connectionId) async {
    await _db
        .from('ha_entities')
        .delete()
        .eq('connection_id', connectionId);
  }

  /// Get entity count by domain
  Future<Map<String, int>> getEntityCountByDomain() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return {};

    final data = await _db
        .from('ha_entities')
        .select('domain')
        .eq('user_id', userId)
        .eq('is_visible', true);

    final counts = <String, int>{};
    for (final row in data) {
      final domain = row['domain'] as String;
      counts[domain] = (counts[domain] ?? 0) + 1;
    }
    return counts;
  }
}
