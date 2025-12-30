import 'package:flutter/material.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/widgets/auth_wrapper.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lawdesk/screens/onboarding/onboarding_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lawdesk/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SupabaseConfig.initialize();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;
  await connectivityService.initialize();
  await notificationService.initialize();

  runApp(MyApp(seenOnboarding: seenOnboarding));
}

class MyApp extends StatefulWidget {
  final bool seenOnboarding;

  const MyApp({Key? key, required this.seenOnboarding}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _getFcmToken();
  }

  Future<void> _getFcmToken() async {
    final _supabase = Supabase.instance.client;
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await FirebaseMessaging.instance.requestPermission();
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _supabase.from('profiles').upsert({
            'id': user.id,
            'fcm_token': fcmToken,
          });
        }
        // Listen for token refresh
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
          await _supabase.from('profiles').upsert({
            'id': user.id,
            'fcm_token': newToken,
          });
        });
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'LawDesk',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'SF Pro Display',
        ),
        home: widget.seenOnboarding == true
            ? const AuthWrapper()
            : const OnBoardingScreen(),
      ),
    );
  }
}
