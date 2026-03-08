import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔍 Testing Supabase connection from Flutter app...');
  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnon,
    );
    print('✅ Supabase initialized successfully');
    
    // Test basic connection
    final client = Supabase.instance.client;
    
    // Try to make a simple request
    final response = await client
        .from('profiles')
        .select('count')
        .count(CountOption.exact)
        .timeout(const Duration(seconds: 10));
    
    print('✅ Supabase connection test successful: $response');
    
  } catch (e) {
    print('❌ Supabase connection failed: $e');
  }
  
  print('🏁 Test completed');
}
