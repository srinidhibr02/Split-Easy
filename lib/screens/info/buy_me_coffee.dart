import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportUsScreen extends StatelessWidget {
  const SupportUsScreen({super.key});

  Future<void> _openBuyMeACoffee() async {
    final Uri url = Uri.parse('https://www.buymeacoffee.com/zerolpa');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text('Support Us'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orangeAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundImage: const AssetImage('images/split_easy.png'),
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              "Buy Us a Coffee ☕",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.brown.shade700,
              ),
            ),
            const SizedBox(height: 12),

            // Subtitle / message
            Text(
              "If you enjoy using SplitEasy and want to support future updates, "
              "consider buying us a coffee! Every bit helps us keep improving.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),

            // Coffee button
            ElevatedButton.icon(
              onPressed: _openBuyMeACoffee,
              icon: const Icon(Icons.local_cafe_rounded, color: Colors.white),
              label: const Text(
                "Buy us a coffee",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent.shade200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.orangeAccent.withOpacity(0.4),
              ),
            ),

            const SizedBox(height: 20),

            // Optional social/share buttons
            TextButton.icon(
              onPressed: () async {
                final Uri url = Uri.parse(
                  'https://www.buymeacoffee.com/zerolpa',
                ); // Optional social
                if (!await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                )) {
                  throw 'Could not launch $url';
                }
              },
              icon: const Icon(Icons.share_rounded, color: Colors.grey),
              label: const Text(
                "Share our app ❤️",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
