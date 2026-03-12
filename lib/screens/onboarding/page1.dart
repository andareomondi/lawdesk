import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OnboardingPage1 extends StatelessWidget {
  const OnboardingPage1({Key? key}) : super(key: key);

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
              Lottie.asset(
                'assets/complete.json',
                width: 400,
                height: 250,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              // Title
              Text(
                'Manage & Track Cases',
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
                'Keep all your cases organized in one place. Track progress, deadlines, and important milestones effortlessly.',
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
