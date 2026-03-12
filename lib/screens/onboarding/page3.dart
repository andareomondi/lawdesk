import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OnboardingPage3 extends StatelessWidget {
  const OnboardingPage3({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon
              Lottie.asset(
                'assets/news.json',
                width: 400,
                height: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              // Title
              Text(
                'Access Anywhere',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                'Access your cases and court dates from anywhere. Stay updated and never miss an important deadline.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
