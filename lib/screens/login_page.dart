import 'dart:async';
import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/widgets/otp_input.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _authSevice = AuthServices();

  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpVerifyController = TextEditingController();
  bool showOTP = false;
  int timerSeconds = 30;
  Timer? countdownTimer;
  String verificationId = "";
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  Future<void> profileCompletion() async {
    final isProfileCompleted = _authSevice.isProfileCompleted();
    if (await isProfileCompleted) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/homeScreen");
    } else {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/userInfo");
    }
  }

  Future<void> sendOTP() async {
    if (phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid 10-digit phone number"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    await _authSevice.sendOTP(
      phoneNumber: '+91${phoneController.text.trim()}',
      onLoginSuccess: () async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login Successful"),
            backgroundColor: Colors.green,
          ),
        );
        profileCompletion();
      },
      onLoginFailed: (e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      },
      onOtpSent: (String verId) {
        if (!mounted) return;
        setState(() {
          verificationId = verId;
          showOTP = true;
          isLoading = false;
          startTimer();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("OTP Sent Successfully"),
            backgroundColor: Colors.green,
          ),
        );
      },
    );
  }

  Future<void> verifyOTP(String otp) async {
    try {
      setState(() => isLoading = true);
      await _authSevice.verifyOTP(otp: otp, verificationId: verificationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login Successful"),
          backgroundColor: Colors.green,
        ),
      );
      profileCompletion();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid OTP"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void startTimer() {
    timerSeconds = 30;
    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerSeconds == 0) {
        timer.cancel();
        if (mounted) {
          setState(() => showOTP = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("OTP Expired. Please try again.")),
          );
        }
      } else {
        if (mounted) setState(() => timerSeconds--);
      }
    });
  }

  void stopTimer() {
    countdownTimer?.cancel();
  }

  @override
  void dispose() {
    stopTimer();
    _animationController.dispose();
    phoneController.dispose();
    otpVerifyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top Right Circle Background with shadow
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
                  border: Border.all(
                    color: secondary.withAlpha((255 * 0.3).round()),
                    width: 4,
                  ),
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with Hero animation ready
                      Hero(
                        tag: 'app_logo',
                        child: Image.asset(
                          "images/split_easy.png",
                          height: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Welcome Text
                      if (!showOTP) ...[
                        Text(
                          "Welcome back",
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Enter your phone number to continue",
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 40),
                      ],

                      // Animated Container for smooth transitions
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                        child: showOTP
                            ? _buildOTPSection()
                            : _buildPhoneSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: primary),
                        const SizedBox(height: 16),
                        Text(
                          "Please wait...",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      key: const ValueKey('phone_section'),
      children: [
        // Phone Number Field with enhanced styling
        Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.05).round()),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            style: const TextStyle(fontSize: 16, letterSpacing: 1.2),
            decoration: InputDecoration(
              counterText: "",
              labelText: "Phone Number",
              labelStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: primary),
                    const SizedBox(width: 8),
                    Text(
                      "+91",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.only(left: 8),
                    ),
                  ],
                ),
              ),
              hintText: '00000 00000',
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Enhanced Login Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : sendOTP,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              disabledBackgroundColor: primary.withAlpha((255 * 0.6).round()),
              elevation: 4,
              shadowColor: primary.withAlpha((255 * 0.4).round()),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              "Send OTP",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPSection() {
    return Column(
      key: const ValueKey('otp_section'),
      children: [
        // OTP Header
        Text(
          "Verify OTP",
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the code sent to +91${phoneController.text}",
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // OTP Input Widget
        OtpInputWidget(
          onSubmit: (otp) async {
            await verifyOTP(otp);
          },
        ),
        const SizedBox(height: 24),

        // Timer Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: timerSeconds <= 10 ? Colors.red[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: timerSeconds <= 10 ? Colors.red[200]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                color: timerSeconds <= 10 ? Colors.red[700] : Colors.grey[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "OTP expires in $timerSeconds seconds",
                style: TextStyle(
                  color: timerSeconds <= 10
                      ? Colors.red[700]
                      : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Resend OTP Button
        TextButton.icon(
          onPressed: isLoading
              ? null
              : () {
                  stopTimer();
                  setState(() => showOTP = false);
                  phoneController.clear();
                },
          icon: const Icon(Icons.refresh),
          label: const Text("Change Number"),
          style: TextButton.styleFrom(
            foregroundColor: primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
