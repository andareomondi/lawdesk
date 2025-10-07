import 'package:flutter/material.dart';
import 'package:lawdesk/auth/login.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/pages/profile/profile.dart';
import 'package:lawdesk/dashboard.dart';
// import 'package:lawdesk/pages/cases/case_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://biurtsyinsijvfwqsfta.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpdXJ0c3lpbnNpanZmd3FzZnRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1OTkzMzAsImV4cCI6MjA3NTE3NTMzMH0.pOkVRQP8EQkJWKKwOdWd-nMuoU6a2jKPO-TNlcOResQ',
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const Dashboard(),
        '/profile': (context) => const ProfileScreen(),
      },
      title: 'LawDesk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: const AuthDirector(),
    );
  }
}


class AuthDirector extends StatefulWidget {
  const AuthDirector({super.key});

  @override
  State<AuthDirector> createState() => _AuthDirectorState();
}

class _AuthRedirectorState extends State<AuthRedirector> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        // User is signed out, go to login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        // User is signed in, go to dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const Dashboard()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while the auth state is being checked
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
