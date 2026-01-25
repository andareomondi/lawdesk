import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  subscriptionEnded,
  blocked, // For is_activated = false
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final _supabase = Supabase.instance.client;

  User? _user;
  Map<String, dynamic>? _profile;
  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;

  // Getters
  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  AuthStatus get status => _status;
  bool get isLoading => _isLoading;
  bool get isInitializing => _status == AuthStatus.initial;

  AuthProvider() {
    _initialize();
  }

  // Initialize: check if user is already logged in on app startup
  Future<void> _initialize() async {
    _status = AuthStatus.initial;
    notifyListeners();

    // Start a timer for a minimum of 2 seconds
    final minimumDelay = Future.delayed(const Duration(seconds: 2));

    try {
      _user = _authService.currentUser;

      // Perform the subscription check logic
      final authCheck = _fetchAndCheckSubscription();

      // Future.wait ensures BOTH the delay AND the auth check finish
      // before we move past this line.
      await Future.wait([minimumDelay, authCheck]);
    } catch (e) {
      debugPrint('Initialization error: $e');
      _status = AuthStatus.unauthenticated;
    } finally {
      // Only now do we update the UI to switch away from Splash
      notifyListeners();
    }
  }

  /// Fetches profile and determines if user can access dashboard
  /// Implements Option C: Checks cache if offline
  Future<void> _fetchAndCheckSubscription() async {
    if (_user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to fetch latest data from Supabase
      try {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', _user!.id)
            .single();

        _profile = response;

        // Cache critical fields for offline access
        await prefs.setString(
          'cached_sub_date',
          response['subscription_end_date'] ?? '',
        );
        await prefs.setBool(
          'cached_is_activated',
          response['is_activated'] ?? false,
        );
      } catch (networkError) {
        debugPrint(
          'Network error fetching profile, using cache: $networkError',
        );
        // Fallback to cache
        _profile = {
          'subscription_end_date': prefs.getString('cached_sub_date'),
          'is_activated':
              prefs.getBool('cached_is_activated') ??
              true, // optimistic default if no cache
        };
      }

      // EVALUATE STATUS
      final isActivated = _profile?['is_activated'] ?? true;
      final subDateStr = _profile?['subscription_end_date'];

      if (!isActivated) {
        _status = AuthStatus.blocked;
        return;
      }

      if (subDateStr != null) {
        final subDate = DateTime.parse(
          subDateStr,
        ).toLocal(); // Convert timestamptz to local
        final now = DateTime.now();

        if (now.isAfter(subDate)) {
          _status = AuthStatus.subscriptionEnded;
        } else {
          _status = AuthStatus.authenticated;
        }
      } else {
        // Fallback if no date is set (e.g. legacy users) -> Allow access or Block based on policy
        // Assuming allow for now, or you can set strict default
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      debugPrint('Error in subscription check: $e');
      // If critical failure, default to unauthenticated to be safe, or authenticated to be nice
      _status = AuthStatus.authenticated;
    }
  }

  // Exposed method for the "Refresh" button on the blocked screen
  Future<void> refreshProfile() async {
    _isLoading = true;
    notifyListeners();
    await _fetchAndCheckSubscription();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.signUp(email: email, password: password);
      _user = _authService.currentUser;
      // Fetch the profile created by the trigger
      await _fetchAndCheckSubscription();
    } catch (e) {
      throw Exception('Sign up error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      _user = _authService.currentUser;
      await _fetchAndCheckSubscription();
    } catch (e) {
      throw Exception('Sign in error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_sub_date');
      await prefs.remove('cached_is_activated');

      _user = null;
      _profile = null;
      _status = AuthStatus.unauthenticated;
    } catch (e) {
      throw Exception('Sign out error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
