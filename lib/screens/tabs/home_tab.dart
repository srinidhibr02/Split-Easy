import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/firestore_services.dart';

class HomeTab extends StatefulWidget {
  // ignore: use_super_parameters
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final FirestoreServices _firestoreServices = FirestoreServices();
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreServices.getFriendsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No Friends found"));
          }

          final friends = snapshot.data!;
          double total = 0;

          // filter friends based on selected tab
          final filtered = friends.where((friend) {
            final balance = (friend['balance'] ?? 0) as num; // ✅ safe fallback
            if (selectedTab == 1) return balance < 0; // I owe
            if (selectedTab == 2) return balance > 0; // Owns me
            return true;
          }).toList();

          for (var f in friends) {
            total += (f['balance'] ?? 0) as num; // ✅ safe fallback
          }

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Summary",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "₹${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _tabButton("Overall", 0),
                    _tabButton("I Owe", 1),
                    _tabButton("Owns Me", 2),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final friend = filtered[index];
                      final balance = (friend['balance'] ?? 0) as num; // ✅ safe
                      final avatarUrl =
                          friend['avatar'] ?? "default_avatar_url";
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(avatarUrl),
                        ),
                        title: Text(friend['name'] ?? "Unknown"),
                        trailing: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: balance >= 0 ? "+₹" : "-₹",
                                style: TextStyle(
                                  color: balance > 0
                                      ? Colors.green
                                      : balance < 0
                                      ? Colors.red
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              TextSpan(
                                text: balance.abs().toStringAsFixed(2),
                                style: TextStyle(
                                  color: balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
