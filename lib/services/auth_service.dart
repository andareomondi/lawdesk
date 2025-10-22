import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/config/supabase_config.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Check if user is currently logged in
  bool get isLoggedIn => _client.auth.currentSession != null;

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Sign up with email and password
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
      await _client.auth.signUp(email: email, password: password);
  }

  // Sign in with email and password
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
      await _client.auth.signInWithPassword(email: email, password: password);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: $e');
    }
  }
}
