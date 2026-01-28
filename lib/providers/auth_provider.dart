import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  bool _isInitializing = true;

  // Getters
  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  AuthProvider() {
    _initialize();
  }

  // Initialize: check if user is already logged in on app startup
  Future<void> _initialize() async {
    // We don't need to notify listeners at the very start of constructor
    // _isInitializing is already true by default

    try {
      // Just grab the current user from the service
      _user = _authService.currentUser;
    } catch (e) {
      // If checking the user fails, we assume they are logged out.
      // We catch this silently so the app doesn't crash on startup.
      _user = null;
      debugPrint('Auth initialization warning: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Sign up
  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // We wait for the service to finish
      await _authService.signUp(email: email, password: password);

      notifyListeners();
    } catch (e) {
      // CRITICAL CHANGE: We use 'rethrow' instead of throwing a new Exception.
      // This allows the specific AuthException (with status codes) to reach your UI.
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in
  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      // Update local user state
      _user = response.user;

      notifyListeners();
    } catch (e) {
      // CRITICAL CHANGE: Rethrow allows login_screen.dart to see e.statusCode == '400'
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      // For sign out, we usually don't want to block the UI,
      // but rethrowing is fine if you want to show a toast.
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
