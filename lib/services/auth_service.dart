import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:lawdesk/services/offline_storage_service.dart';

class AuthService {
  SupabaseClient get _client => SupabaseConfig.client;
  OfflineStorageService get _offlineStorage => OfflineStorageService();

  bool get isLoggedIn => _client.auth.currentSession != null;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

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
          code: 'user_already_exists',
        );
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(
        'An unexpected error occurred during sign up: ${e.toString()}',
      );
    }
  }

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
      await _offlineStorage.clearCache();
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
