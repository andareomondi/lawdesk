import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lawdesk/screens/onboarding/page1.dart';
import 'package:lawdesk/screens/onboarding/page2.dart';
import 'package:lawdesk/screens/onboarding/page3.dart';

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
            children: [
            OnboardingPage1(),
            OnboardingPage2(),
            OnboardingPage3(),
              
            ],
          ),
           // smooth indicator
           Container(
           alignment: Alignment(0, 0.8),
           child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
             children: [
             // skip
             GestureDetector(
             onTap: () {
               _controller.jumpToPage(2);
             },
             child: Text('Skip', style: TextStyle(fontSize: 18),)
             ),

               SmoothPageIndicator(controller: _controller, count: 3, effect: WormEffect(), ),
                
                // Next
                isLastPage ?
                GestureDetector(
                onTap: () async{
                  // update local storage that we have already seen this intro
                  final prefs = await SharedPreferences.getInstance(); 
                  await prefs.setBool('seenOnboarding', true);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
                },
                child: Text('Finish', style: TextStyle(fontSize: 18),)
                )
                : GestureDetector(
                onTap: () {
                  _controller.nextPage(duration: Duration(milliseconds:500), curve: Curves.easeIn,);
                },
                child: Text('Next'),

                ),
                 
             GestureDetector(
             onTap: () {
               _controller.jumpToPage(2);
             },
             child: Text('Skip', style: TextStyle(fontSize: 18),)
             ),
             ],
           )),
        ],
      ),
    );
  }
}

