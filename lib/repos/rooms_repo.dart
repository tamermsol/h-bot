import '../core/supabase_client.dart';
import '../demo/demo_data.dart';
import '../models/room.dart';

class RoomsRepo {
  /// List all rooms in a home
  Future<List<Room>> listRooms(String homeId) async {
    if (isDemoMode) return DemoData.getRooms(homeId);
    try {
      final response = await supabase
          .from('rooms')
          .select('*')
          .eq('home_id', homeId)
          .order('sort_order');

      return (response as List).map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to load rooms: $e';
    }
  }

  /// Create a new room
  Future<Room> createRoom(String homeId, String name, int sortOrder) async {
    try {
      final response = await supabase
          .from('rooms')
          .insert({
            'home_id': homeId,
            'name': name,
            'sort_order': sortOrder,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return Room.fromJson(response);
    } catch (e) {
      throw 'Failed to create room: $e';
    }
  }

  /// Update a room
  Future<Room> updateRoom(
    String roomId, {
    String? name,
    int? sortOrder,
    String? backgroundImageUrl,
    String? iconName,
    bool clearBackground = false,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (name != null) updates['name'] = name;
      if (sortOrder != null) updates['sort_order'] = sortOrder;
      if (iconName != null) updates['icon_name'] = iconName;

      // Handle background image: explicit null to remove, or new URL to set
      if (clearBackground) {
        updates['background_image_url'] = null;
      } else if (backgroundImageUrl != null) {
        updates['background_image_url'] = backgroundImageUrl;
      }

      final response = await supabase
          .from('rooms')
          .update(updates)
          .eq('id', roomId)
          .select()
          .single();

      return Room.fromJson(response);
    } catch (e) {
      throw 'Failed to update room: $e';
    }
  }

  /// Delete a room
  Future<void> deleteRoom(String roomId) async {
    try {
      await supabase.from('rooms').delete().eq('id', roomId);
    } catch (e) {
      throw 'Failed to delete room: $e';
    }
  }

  /// Get the next sort order for a new room in a home
  Future<int> getNextSortOrder(String homeId) async {
    try {
      final response = await supabase
          .from('rooms')
          .select('sort_order')
          .eq('home_id', homeId)
          .order('sort_order', ascending: false)
          .limit(1);

      if (response.isEmpty) return 0;
      return (response.first['sort_order'] as int) + 1;
    } catch (e) {
      return 0; // Default to 0 if query fails
    }
  }

  /// Reorder rooms in a home
  Future<void> reorderRooms(List<String> roomIds) async {
    try {
      final futures = <Future>[];
      for (int i = 0; i < roomIds.length; i++) {
        futures.add(
          supabase
              .from('rooms')
              .update({
                'sort_order': i,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', roomIds[i]),
        );
      }
      await Future.wait(futures);
    } catch (e) {
      throw 'Failed to reorder rooms: $e';
    }
  }
}
