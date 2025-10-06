import 'package:flutter/material.dart';
import 'package:lawdesk/auth/login.dart';
import 'package:lawdesk/dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      title: 'LawDesk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'SF Pro Display',
      ),
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          // Check if user is logged in
          if (snapshot.hasData && snapshot.data!.session != null) {
            return const Dashboard();
          }
          
          // Show login page if not logged in
          return const LoginPage();
        },
      ),
    );
  }
}
