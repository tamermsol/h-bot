import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wifi_profile.dart';

/// Repository for managing user Wi-Fi profiles
class WiFiProfilesRepo {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all Wi-Fi profiles for the current user
  Future<List<WiFiProfile>> getUserProfiles() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await _supabase
          .from('wifi_profiles')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => WiFiProfile.fromJson(json))
          .toList();
    } catch (e) {
      throw 'Failed to get Wi-Fi profiles: $e';
    }
  }

  /// Get the default Wi-Fi profile for the current user
  Future<WiFiProfile?> getDefaultProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await _supabase
          .from('wifi_profiles')
          .select()
          .eq('user_id', user.id)
          .eq('is_default', true)
          .maybeSingle();

      if (response == null) return null;
      return WiFiProfile.fromJson(response);
    } catch (e) {
      throw 'Failed to get default Wi-Fi profile: $e';
    }
  }

  /// Create a new Wi-Fi profile
  Future<WiFiProfile> createProfile(WiFiProfileRequest request) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // If this is set as default, unset other defaults first
      if (request.isDefault) {
        await _unsetAllDefaults();
      }

      final response = await _supabase
          .from('wifi_profiles')
          .insert({
            'user_id': user.id,
            'ssid': request.ssid,
            'password': request.password,
            'is_default': request.isDefault,
          })
          .select()
          .single();

      return WiFiProfile.fromJson(response);
    } catch (e) {
      throw 'Failed to create Wi-Fi profile: $e';
    }
  }

  /// Update an existing Wi-Fi profile
  Future<WiFiProfile> updateProfile(String profileId, WiFiProfileRequest request) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // If this is set as default, unset other defaults first
      if (request.isDefault) {
        await _unsetAllDefaults();
      }

      final response = await _supabase
          .from('wifi_profiles')
          .update({
            'ssid': request.ssid,
            'password': request.password,
            'is_default': request.isDefault,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId)
          .eq('user_id', user.id)
          .select()
          .single();

      return WiFiProfile.fromJson(response);
    } catch (e) {
      throw 'Failed to update Wi-Fi profile: $e';
    }
  }

  /// Delete a Wi-Fi profile
  Future<void> deleteProfile(String profileId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      await _supabase
          .from('wifi_profiles')
          .delete()
          .eq('id', profileId)
          .eq('user_id', user.id);
    } catch (e) {
      throw 'Failed to delete Wi-Fi profile: $e';
    }
  }

  /// Set a profile as default
  Future<WiFiProfile> setAsDefault(String profileId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Unset all other defaults first
      await _unsetAllDefaults();

      // Set this profile as default
      final response = await _supabase
          .from('wifi_profiles')
          .update({
            'is_default': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', profileId)
          .eq('user_id', user.id)
          .select()
          .single();

      return WiFiProfile.fromJson(response);
    } catch (e) {
      throw 'Failed to set Wi-Fi profile as default: $e';
    }
  }

  /// Check if a profile with the same SSID already exists
  Future<WiFiProfile?> findBySSID(String ssid) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      final response = await _supabase
          .from('wifi_profiles')
          .select()
          .eq('user_id', user.id)
          .eq('ssid', ssid)
          .maybeSingle();

      if (response == null) return null;
      return WiFiProfile.fromJson(response);
    } catch (e) {
      throw 'Failed to find Wi-Fi profile by SSID: $e';
    }
  }

  /// Unset all default profiles for the current user
  Future<void> _unsetAllDefaults() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('wifi_profiles')
        .update({
          'is_default': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', user.id)
        .eq('is_default', true);
  }

  /// Get or create a profile for the current network
  Future<WiFiProfile?> getOrCreateCurrentNetworkProfile() async {
    try {
      // This would typically get the current network SSID
      // For now, we'll just return the default profile
      return await getDefaultProfile();
    } catch (e) {
      return null;
    }
  }

  /// Stream of Wi-Fi profiles for real-time updates
  Stream<List<WiFiProfile>> watchUserProfiles() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('wifi_profiles')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => WiFiProfile.fromJson(json)).toList());
  }
}
