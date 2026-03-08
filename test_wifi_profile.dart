import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/env.dart';

void main() async {
  print('🔍 Testing Wi-Fi profile saving...');

  try {
    // Initialize Supabase
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnon);
    print('✅ Supabase initialized successfully');

    // Test if tables exist
    final client = Supabase.instance.client;
    final tablesResponse = await client
        .from('user_wifi_profiles')
        .select('count')
        .count(CountOption.exact);

    print('✅ user_wifi_profiles table exists: $tablesResponse');

    final defaultsResponse = await client
        .from('app_defaults')
        .select('count')
        .count(CountOption.exact);

    print('✅ app_defaults table exists: $defaultsResponse');

    // Check current user
    final user = client.auth.currentUser;
    print('Current user: ${user?.id ?? 'Not signed in'}');

    if (user != null) {
      // Test inserting a Wi-Fi profile
      final testProfile = {
        'user_id': user.id,
        'ssid': 'TestNetwork',
        'password_enc': 'test_password_123',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final insertResponse = await client
          .from('user_wifi_profiles')
          .upsert(testProfile, onConflict: 'user_id,ssid')
          .select();

      print('✅ Test Wi-Fi profile saved: $insertResponse');

      // Test setting as default
      await client.from('app_defaults').upsert({
        'user_id': user.id,
        'default_wifi_ssid': 'TestNetwork',
      }, onConflict: 'user_id');

      print('✅ Default Wi-Fi profile set');

      // Clean up test data
      await client
          .from('user_wifi_profiles')
          .delete()
          .eq('ssid', 'TestNetwork');

      await client.from('app_defaults').delete().eq('user_id', user.id);

      print('✅ Test data cleaned up');
    }
  } catch (e) {
    print('❌ Test failed: $e');
  }

  print('🏁 Test completed');
}
