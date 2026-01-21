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
      throw Exception('Initialization error: $e');
    }

    _isInitializing = false;
    notifyListeners();
  }

  // Sign up
  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(email: email, password: password);
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      throw Exception('Sign up error: $e');
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
      await _authService.signIn(email: email, password: password);
      _user = _authService.currentUser;
      notifyListeners();
    } catch (e) {
      throw Exception('Sign in error: $e');
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
      throw Exception('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
