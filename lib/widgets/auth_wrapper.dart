import 'package:flutter/material.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/screens/splash.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:lawdesk/screens/auth/subscription_ended.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // 1. App is starting up / checking session
        if (authProvider.isInitializing) {
          return const Splash();
        }

        // 2. Decide specific screen based on status
        switch (authProvider.status) {
          case AuthStatus.authenticated:
            return const Dashboard();

          case AuthStatus.subscriptionEnded:
          case AuthStatus.blocked:
            // Both blocked and expired users go here, UI handles the text difference
            return const SubscriptionEndedScreen();

          case AuthStatus.unauthenticated:
          default:
            return const LoginPage();
        }
      },
    );
  }
}
