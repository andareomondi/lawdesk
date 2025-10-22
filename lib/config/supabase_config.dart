import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://biurtsyinsijvfwqsfta.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpdXJ0c3lpbnNpanZmd3FzZnRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1OTkzMzAsImV4cCI6MjA3NTE3NTMzMH0.pOkVRQP8EQkJWKKwOdWd-nMuoU6a2jKPO-TNlcOResQ',
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
