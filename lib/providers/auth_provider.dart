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
    _isInitializing = true;
    notifyListeners();

    try {
      _user = _authService.currentUser;
    } catch (e) {
      print('Error initializing auth: $e');
    }

    _isInitializing = false;
    notifyListeners();
  }

  // Sign up
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signUp(email: email, password: password, options:
      {
        'emailRedirectTo': 'https://lawdeskweb.vercel.app/auth/confirm'
      });
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign in
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      print('Sign in error: $e');
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
      print('Sign out error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
