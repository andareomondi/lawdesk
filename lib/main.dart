import 'package:flutter/material.dart';
import 'package:lawdesk/auth_screen.dart';
import 'package:lawdesk/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LawDesk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: isAuthenticated 
        ? const Dashboard()
        : Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AuthScreen(
                onLoginSuccess: () {
                  setState(() {
                    isAuthenticated = true;
                  });
                },
              ),
            ),
          ),
    );
  }
}
