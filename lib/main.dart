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
