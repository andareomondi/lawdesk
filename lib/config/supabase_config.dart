import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['supabase_url']!,
      anonKey: dotenv.env['supabase_anon_key']!,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
