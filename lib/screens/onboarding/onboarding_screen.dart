import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({Key? key}) : super(key: key);

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _controller = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            children: [
              Container(
                color: Colors.red,
                child: const Center(
                  child: Text(
                    'Welcome to the App!',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),
              Container(
                color: Colors.green,
                child: const Center(
                  child: Text(
                    'Discover new features.',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),
              Container(
                color: Colors.blue,
                child: const Center(
                  child: Text(
                    'Get Started Now!',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
           // smooth indicator
           Container(
           alignment: Alignment(0, 0.8),
           child: SmoothPageIndicator(controller: _controller, count: 3, effect: WormEffect(), )),
        ],
      ),
    );
  }
}

