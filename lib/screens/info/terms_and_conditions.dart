import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Terms & Conditions",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.2,
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Replace this in your TermsAndConditionsScreen build:
              const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('images/split_easy.png'),
              ),

              const SizedBox(height: 16),
              const Text(
                "Welcome to split_easy!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Please read these Terms & Conditions before using split_easy.",
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  thickness: 4,
                  radius: const Radius.circular(8),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "1. Acceptance of Terms",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "By using split_easy, you agree to these terms and conditions. If you do not agree, please do not use the app.",
                        ),
                        SizedBox(height: 16),
                        Text(
                          "2. Usage & Responsibilities",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "You agree to use split_easy only for lawful purposes and are responsible for any information you input or share with group members.",
                        ),
                        SizedBox(height: 16),
                        Text(
                          "3. Data & Privacy",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "We value your privacy. Your personal and group expense data will not be shared with third parties without your consent, except as required by law.",
                        ),
                        SizedBox(height: 16),
                        Text(
                          "4. Limitation of Liability",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "split_easy is provided as-is with no warranties. We are not responsible for any financial loss or disputes arising between users.",
                        ),
                        SizedBox(height: 16),
                        Text(
                          "5. Modifications",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "We reserve the right to modify these terms at any time. Continued use of split_easy means you accept any changes.",
                        ),
                        SizedBox(height: 16),
                        Text(
                          "6. Contact",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "If you have any questions or concerns, email us at support@spliteasy.com.",
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Thank you for using split_easy!",
                          style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    iconColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.3,
                      color: primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
