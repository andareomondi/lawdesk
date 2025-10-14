import 'package:flutter/material.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/screens/splash_screen.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Still loading? Show splash screen
        if (authProvider.isInitializing) {
          return const SplashScreen();
        }

        // User logged in? Show home screen
        if (authProvider.isLoggedIn) {
          return const Dashboard();
        }

        // User not logged in? Show login screen
        return const LoginPage();
      },
    );
  }
}
