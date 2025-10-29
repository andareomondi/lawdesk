import 'package:flutter/material.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/widgets/auth_wrapper.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lawdesk/screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;
  const MyApp({Key? key, required this.seenOnboarding}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'LawDesk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'SF Pro Display'),
        home: seenOnboarding == true
            ? const AuthWrapper()
            : const OnBoardingScreen(),
      ),
    );
  }
}
