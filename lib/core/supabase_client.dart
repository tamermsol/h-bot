import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton access to Supabase client
SupabaseClient get supabase => Supabase.instance.client;
