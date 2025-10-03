import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/constants.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  int totalUsers = 0;
  int totalGroups = 0;
  int totalExpenses = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Count users
      final usersSnapshot = await firestore.collection("users").get();
      final usersCount = usersSnapshot.size;

      // Count groups
      final groupsSnapshot = await firestore.collection("groups").get();
      final groupsCount = groupsSnapshot.size;

      // Count all expenses across all groups
      int expensesCount = 0;
      for (var groupDoc in groupsSnapshot.docs) {
        final expensesSnapshot = await groupDoc.reference
            .collection("expenses")
            .get();
        expensesCount += expensesSnapshot.size;
      }

      setState(() {
        totalUsers = usersCount;
        totalGroups = groupsCount;
        totalExpenses = expensesCount;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "About",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        foregroundColor: primary,

        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      children: [
                        Image.asset(
                          "images/split_easy.png", // your logo
                          height: 100,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Split Easy",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Making expense splitting simple and smart.",
                          style: TextStyle(fontSize: 16, color: secondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(Icons.people, "$totalUsers", "Users"),
                        _statCard(Icons.group, "$totalGroups", "Groups"),
                        _statCard(
                          Icons.receipt_long,
                          "$totalExpenses",
                          "Expenses",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // About text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "About the App",
                          style: TextStyle(
                            color: secondary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Split Easy helps you manage group expenses with ease. "
                          "Whether it's trips, hangouts, or shared living costs, "
                          "our app makes it simple to add expenses, track balances, "
                          "and settle up quickly.",
                          style: TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    "Version 1.0.0",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "© 2025 Split Easy",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Icon(icon, color: primary, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }
}
