import 'dart:async';
import 'package:flutter/material.dart';
import 'package:split_easy/services/auth_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  final userServices = AuthServices();

  @override
  void initState() {
    super.initState();
    //Splash Logic
    _timer = Timer(Duration(seconds: 3), () {
      _checkLogin();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  Future<void> _checkLogin() async {
    if (userServices.checkLogin()) {
      // print("Already Logged in");
      Navigator.pushReplacementNamed(context, "/userInfo");
    } else {
      // print("You must login");
      Navigator.pushReplacementNamed(context, "/authScreen");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset("images/split_easy.png"),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "Made in India",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.favorite, color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
