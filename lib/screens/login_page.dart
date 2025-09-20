import 'dart:async';

import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/widgets/otp_input.dart'; // Make sure secondary color is defined here.

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authSevice = AuthServices();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpVerifyController = TextEditingController();
  bool showOTP = false;
  int timerSeconds = 30;
  Timer? countdownTimer;
  String verificationId = "";

  Future<void> profileCompletion() async {
    final isProfileCompleted = _authSevice.isProfileCompleted();
    if (await isProfileCompleted) {
      Navigator.pushReplacementNamed(context, "/homeScreen");
    } else {
      Navigator.pushReplacementNamed(context, "/userInfo");
    }
  }

  Future<void> sendOTP() async {
    await _authSevice.sendOTP(
      phoneNumber: '+91${phoneController.text.trim()}',
      onLoginSuccess: () async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Login Successful")));
        profileCompletion();
      },
      onLoginFailed: (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
      },
      onOtpSent: (String verId) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("OTP Sent")));
        setState(() {
          verificationId = verId;
          showOTP = true;
          startTimer();
        });
      },
    );
  }

  Future<void> verifyOTP(String otp) async {
    try {
      await _authSevice.verifyOTP(otp: otp, verificationId: verificationId);
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("Login Successfull")));
      // ignore: use_build_context_synchronously
      profileCompletion();
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("Invalid OTP")));
    }
  }

  //Timer Logic
  void startTimer() {
    timerSeconds = 30;
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (timerSeconds == 0) {
        timer.cancel();
        setState(() {
          showOTP = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP Expired. Please try again.")),
        );
      } else {
        setState(() {
          timerSeconds--;
        });
      }
    });
  }

  void stopTimer() {
    countdownTimer?.cancel();
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top Right Circle Background
          Positioned(
            top: -330,
            right: -330,
            child: Container(
              height: 630,
              width: 630,
              decoration: BoxDecoration(
                color: secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Bottom Left Rotated Border Circle
          Positioned(
            left: -230,
            bottom: -120,
            child: Transform.rotate(
              angle: -0.9999,
              child: Container(
                height: 372,
                width: 372,
                decoration: BoxDecoration(
                  border: Border.all(color: secondary, width: 4),
                ),
              ),
            ),
          ),
          // Main Column Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  "images/split_easy.png",
                  height: 300,
                  fit: BoxFit.contain,
                ),

                if (!showOTP) ...[
                  // Phone Number Field
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      counterText: "",
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: '00000-00000',
                    ),
                  ),
                  SizedBox(height: 20),
                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Login",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  //verify OTP Screen
                  OtpInputWidget(
                    onSubmit: (otp) async {
                      await verifyOTP(otp);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
