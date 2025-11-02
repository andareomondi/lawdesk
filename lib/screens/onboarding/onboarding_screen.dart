import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lawdesk/screens/onboarding/page1.dart';
import 'package:lawdesk/screens/onboarding/page2.dart';
import 'package:lawdesk/screens/onboarding/page3.dart';
import 'package:lawdesk/dashboard.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({Key? key}) : super(key: key);

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isLastPage = index == 2;
              });
            },
            children: const [
              OnboardingPage1(),
              OnboardingPage2(),
              OnboardingPage3(),
            ],
          ),
          // Smooth indicator and navigation buttons
          Container(
            alignment: const Alignment(0, 0.8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Skip button
                GestureDetector(
                  onTap: () {
                    _controller.jumpToPage(2);
                  },
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 18),
                  ),
                ),

                // Page indicator
                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: const WormEffect(),
                ),

                // Next or Finish button
                isLastPage
                    ? GestureDetector(
                        onTap: () async {
                          // Update local storage that we have already seen this intro
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('seenOnboarding', true);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Dashboard(),
                            ),
                          );
                        },
                        child: const Text(
                          'Finish',
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : GestureDetector(
                        onTap: () {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeIn,
                          );
                        },
                        child: const Text(
                          'Next',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
