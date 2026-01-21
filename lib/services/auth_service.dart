import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/config/supabase_config.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Check if user is currently logged in
  bool get isLoggedIn => _client.auth.currentSession != null;

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Sign up with email and password

  Future<void> signUp({required String email, required String password}) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      // If identities is empty, the user is already registered and confirmed.
      // We throw an exception to "prevent" further signup logic.
      if (response.user?.identities?.isEmpty ?? false) {
        throw const AuthException(
          'This email is already in use. Please sign in instead.',
        );
      }
    } on AuthException catch (e) {
      // This will catch your custom throw AND any Supabase errors
      throw AuthException('$e.message');
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  // Sign in with email and password
  Future<void> signIn({required String email, required String password}) async {
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
