import '../core/supabase_client.dart';
import '../demo/demo_data.dart';
import '../models/home.dart';

class HomesRepo {
  /// List all homes the current user has access to
  Future<List<Home>> listMyHomes() async {
    if (isDemoMode) return DemoData.homes;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // First, get homes where user is the owner
      final ownedHomesResponse = await supabase
          .from('homes')
          .select('*')
          .eq('owner_id', user.id)
          .order('created_at');

      // Then, get homes where user is a member
      final memberHomesResponse = await supabase
          .from('home_members')
          .select('''
            homes!inner(
              id,
              owner_id,
              name,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', user.id);

      // Combine the results
      final Set<String> seenHomeIds = {};
      final List<Home> allHomes = [];

      // Add owned homes
      for (final homeJson in ownedHomesResponse as List) {
        final home = Home.fromJson(homeJson);
        if (!seenHomeIds.contains(home.id)) {
          allHomes.add(home);
          seenHomeIds.add(home.id);
        }
      }

      // Add member homes (avoiding duplicates)
      for (final memberRecord in memberHomesResponse as List) {
        final homeJson = memberRecord['homes'];
        final home = Home.fromJson(homeJson);
        if (!seenHomeIds.contains(home.id)) {
          allHomes.add(home);
          seenHomeIds.add(home.id);
        }
      }

      // Sort by creation date
      allHomes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return allHomes;
    } catch (e) {
      throw 'Failed to load homes: $e';
    }
  }

  /// Create a new home
  Future<Home> createHome(String name) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await supabase
          .from('homes')
          .insert({
            'owner_id': user.id,
            'name': name,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Add the creator as owner in home_members
      await supabase.from('home_members').insert({
        'home_id': response['id'],
        'user_id': user.id,
        'role': 'owner',
        'created_at': DateTime.now().toIso8601String(),
      });

      return Home.fromJson(response);
    } catch (e) {
      throw 'Failed to create home: $e';
    }
  }

  /// Rename a home
  Future<void> renameHome(String homeId, String name) async {
    try {
      await supabase
          .from('homes')
          .update({
            'name': name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', homeId);
    } catch (e) {
      throw 'Failed to rename home: $e';
    }
  }

  /// Update home background image
  Future<void> updateHomeBackgroundImage(
    String homeId,
    String? backgroundImageUrl,
  ) async {
    try {
      await supabase
          .from('homes')
          .update({
            'background_image_url': backgroundImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', homeId);
    } catch (e) {
      throw 'Failed to update home background image: $e';
    }
  }

  /// Delete a home
  Future<void> deleteHome(String homeId) async {
    try {
      // Delete home_members first (foreign key constraint)
      await supabase.from('home_members').delete().eq('home_id', homeId);

      // Delete the home
      await supabase.from('homes').delete().eq('id', homeId);
    } catch (e) {
      throw 'Failed to delete home: $e';
    }
  }

  /// List members of a home
  Future<List<Map<String, dynamic>>> listHomeMembers(String homeId) async {
    try {
      final response = await supabase
          .from('home_members')
          .select('''
            *,
            profiles!inner(id, full_name)
          ''')
          .eq('home_id', homeId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw 'Failed to load home members: $e';
    }
  }

  /// Add a member to a home
  Future<void> addMember(
    String homeId,
    String userId, {
    String role = 'member',
  }) async {
    try {
      await supabase.from('home_members').insert({
        'home_id': homeId,
        'user_id': userId,
        'role': role,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw 'Failed to add member: $e';
    }
  }

  /// Remove a member from a home
  Future<void> removeMember(String homeId, String userId) async {
    try {
      await supabase
          .from('home_members')
          .delete()
          .eq('home_id', homeId)
          .eq('user_id', userId);
    } catch (e) {
      throw 'Failed to remove member: $e';
    }
  }

  /// Update member role
  Future<void> updateMemberRole(
    String homeId,
    String userId,
    String role,
  ) async {
    try {
      await supabase
          .from('home_members')
          .update({'role': role})
          .eq('home_id', homeId)
          .eq('user_id', userId);
    } catch (e) {
      throw 'Failed to update member role: $e';
    }
  }
}
