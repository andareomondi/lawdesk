import 'package:flutter/material.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/screens/splash.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:lawdesk/screens/auth/subscription_ended.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// AuthStatus enum
// ─────────────────────────────────────────────
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  subscriptionEnded,
  blocked,
}

// ─────────────────────────────────────────────
// SubscriptionProvider
// Holds profile data and subscription state
// so SubscriptionEndedScreen can access it
// ─────────────────────────────────────────────
class SubscriptionProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  AuthStatus _status = AuthStatus.initial;
  bool _isLoading = false;

  Map<String, dynamic>? get profile => _profile;
  AuthStatus get status => _status;
  bool get isLoading => _isLoading;

  Future<void> checkSubscription() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      try {
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        _profile = response;

        await prefs.setString(
          'cached_sub_date',
          response['subscription_end_date'] ?? '',
        );
        await prefs.setBool(
          'cached_is_activated',
          response['is_activated'] ?? true,
        );
      } catch (networkError) {
        debugPrint('Network error, using cache: $networkError');
        _profile = {
          'subscription_end_date': prefs.getString('cached_sub_date') ?? '',
          'is_activated': prefs.getBool('cached_is_activated') ?? true,
        };
      }

      final isActivated = _profile?['is_activated'] ?? true;
      final subDateStr = _profile?['subscription_end_date'] ?? '';

      if (!isActivated) {
        _status = AuthStatus.blocked;
        notifyListeners();
        return;
      }

      if (subDateStr.toString().isNotEmpty) {
        final subDate = DateTime.parse(subDateStr).toLocal();
        _status = DateTime.now().isAfter(subDate)
            ? AuthStatus.subscriptionEnded
            : AuthStatus.authenticated;
      } else {
        _status = AuthStatus.authenticated;
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _isLoading = true;
    notifyListeners();
    await checkSubscription();
    _isLoading = false;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────
// AuthWrapper
// ─────────────────────────────────────────────
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late SubscriptionProvider _subscriptionProvider;

  @override
  void initState() {
    super.initState();
    _subscriptionProvider = SubscriptionProvider();
    _subscriptionProvider.checkSubscription();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _subscriptionProvider,
      child: Consumer2<AuthProvider, SubscriptionProvider>(
        builder: (context, authProvider, subProvider, _) {
          // Show splash while auth initializing OR subscription checking
          if (authProvider.isInitializing ||
              subProvider.status == AuthStatus.initial) {
            return const AnimatedSplashScreenWidget();
          }

          // Not logged in
          if (!authProvider.isLoggedIn) {
            return const LoginPage();
          }

          // Blocked or subscription ended
          if (subProvider.status == AuthStatus.blocked ||
              subProvider.status == AuthStatus.subscriptionEnded) {
            return const SubscriptionEndedScreen();
          }

          // All good
          return const Dashboard();
        },
      ),
    );
  }
}
