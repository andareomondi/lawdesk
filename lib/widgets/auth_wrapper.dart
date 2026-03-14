import 'package:flutter/material.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/screens/splash.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:lawdesk/screens/auth/subscription_ended.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _supabase = Supabase.instance.client;

  bool _isChecking = true;
  bool _isActivated = true;
  bool _subscriptionEnded = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      setState(() => _isChecking = false);
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

        // Cache for offline
        await prefs.setString(
          'cached_sub_date',
          response['subscription_end_date'] ?? '',
        );
        await prefs.setBool(
          'cached_is_activated',
          response['is_activated'] ?? true,
        );

        final isActivated = response['is_activated'] ?? true;
        final subDateStr = response['subscription_end_date'];

        if (!isActivated) {
          setState(() {
            _isActivated = false;
            _isChecking = false;
          });
          return;
        }

        if (subDateStr != null && subDateStr.toString().isNotEmpty) {
          final subDate = DateTime.parse(subDateStr).toLocal();
          final now = DateTime.now();
          setState(() {
            _subscriptionEnded = now.isAfter(subDate);
            _isChecking = false;
          });
        } else {
          setState(() => _isChecking = false);
        }
      } catch (networkError) {
        // Fallback to cache
        debugPrint('Network error, using cache: $networkError');
        final isActivated = prefs.getBool('cached_is_activated') ?? true;
        final subDateStr = prefs.getString('cached_sub_date') ?? '';

        if (!isActivated) {
          setState(() {
            _isActivated = false;
            _isChecking = false;
          });
          return;
        }

        if (subDateStr.isNotEmpty) {
          final subDate = DateTime.parse(subDateStr).toLocal();
          setState(() {
            _subscriptionEnded = DateTime.now().isAfter(subDate);
            _isChecking = false;
          });
        } else {
          setState(() => _isChecking = false);
        }
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show splash while initializing auth OR checking subscription
        if (authProvider.isInitializing || _isChecking) {
          return const Splash();
        }

        // Not logged in
        if (!authProvider.isLoggedIn) {
          return const LoginPage();
        }

        // Logged in but blocked or subscription ended
        if (!_isActivated || _subscriptionEnded) {
          return const SubscriptionEndedScreen();
        }

        // All good
        return const Dashboard();
      },
    );
  }
}
