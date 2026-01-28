import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/config/supabase_config.dart';

class AuthService {
  // Use a getter to ensure we always get the latest instance if config changes,
  // though typically this is static.
  SupabaseClient get _client => SupabaseConfig.client;

  // Check if user is currently logged in
  bool get isLoggedIn => _client.auth.currentSession != null;

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Get current session
  Session? get currentSession => _client.auth.currentSession;

  /// Sign up with email and password
  /// Returns the AuthResponse so the Provider can access user data if needed.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      // EDGE CASE: User Enumeration Protection
      // If Supabase is configured to "Confirm Email", it might return a
      // valid response (fake success) even if the user exists, to prevent
      // hackers from checking which emails are registered.
      // However, if the user exists, the `identities` array is usually empty
      // in the response user object.
      if (response.user != null &&
          (response.user!.identities == null ||
              response.user!.identities!.isEmpty)) {
        throw const AuthException(
          'This email is already in use. Please sign in instead.',
          statusCode: '400', // Manually add a status code so UI can catch it
        );
      }

      return response;
    } on AuthException {
      // CRITICAL FIX: Do not wrap this in a new Exception.
      // Rethrow it so the UI receives the specific 'statusCode' and 'message'.
      rethrow;
    } catch (e) {
      // Handle strictly unknown errors
      throw AuthException(
        'An unexpected error occurred during sign up: ${e.toString()}',
      );
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return response;
    } on AuthException {
      // CRITICAL FIX: Rethrow to preserve statusCode (400 for invalid creds)
      rethrow;
    } catch (e) {
      throw AuthException(
        'An unexpected error occurred during sign in: ${e.toString()}',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  /// Optional: Send password reset email
  /// (Useful for your commented out "Forgot Password" feature)
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }
}
