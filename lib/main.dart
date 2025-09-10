import 'package:flutter/material.dart';
import 'package:split_easy/firebase_options.dart';
import 'package:split_easy/screens/create_group_screen.dart';
import 'package:split_easy/screens/home_screen.dart';
import 'package:split_easy/screens/login_page.dart';
import 'package:split_easy/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:split_easy/screens/user_info.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SplashScreenApp());
}

class SplashScreenApp extends StatelessWidget {
  const SplashScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      // home: const HomeScreen(),
      routes: {
        "/authScreen": (_) => const LoginPage(),
        "/userInfo": (_) => const UserInfo(),
        "/homeScreen": (_) => const HomeScreen(),
        "/createGroupScreen": (_) => CreateGroupScreen(),
      },
    );
  }
}
