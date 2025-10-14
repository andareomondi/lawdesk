import 'package:flutter/material.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:provider/provider.dart';
import 'package:lawdesk/widgets/auth_wrapper.dart';
import 'package:lawdesk/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
        home: const AuthWrapper(),
      ),
    );
  }
}

//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   await Supabase.initialize(
//     url: 'https://biurtsyinsijvfwqsfta.supabase.co',
//     anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJpdXJ0c3lpbnNpanZmd3FzZnRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk1OTkzMzAsImV4cCI6MjA3NTE3NTMzMH0.pOkVRQP8EQkJWKKwOdWd-nMuoU6a2jKPO-TNlcOResQ',
//   );
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       routes: {
//         '/login': (context) => const LoginPage(),
//         '/dashboard': (context) => const Dashboard(),
//         // '/cases': (context) => const CaseListScreen(), TODO: Implement the caselist screen and then uncomment this line
//         '/profile': (context) => const ProfileScreen(),
//       },
//       title: 'LawDesk',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         fontFamily: 'SF Pro Display',
//       ),
//       home: StreamBuilder<AuthState>(
//         stream: Supabase.instance.client.auth.onAuthStateChange,
//         builder: (context, snapshot) {
//           // Show loading indicator while checking auth state
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Scaffold(
//               body: Center(
//                 child: CircularProgressIndicator(),
//               ),
//             );
//           }
//
//           // Check if user is logged in
//           if (snapshot.hasData && snapshot.data!.session != null) {
//             return const Dashboard();
//           }
//
//           // Show login page if not logged in
//           return const LoginPage();
//         },
//       ),
//     );
//   }
// }
