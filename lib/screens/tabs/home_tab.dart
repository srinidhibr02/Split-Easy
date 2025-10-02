import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/group_services.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final GroupService _groupService = GroupService();
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _groupService.getUserGroupsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final groups = snapshot.data ?? [];
          if (groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "No Groups found",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Create or join a group to get started!",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final totalBalance = _groupService.getTotalBalance(groups);

          // Filter groups by tab
          final filtered = groups.where((group) {
            final balance = _groupService.getUserBalanceInGroup(group);
            if (selectedTab == 1) return balance < 0; // I Owe
            if (selectedTab == 2) return balance > 0; // Owed to Me
            return true; // Overall
          }).toList();

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Overall Balance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            totalBalance >= 0 ? "+" : "",
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: totalBalance > 0
                                  ? Colors.green
                                  : totalBalance < 0
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                          Text(
                            "₹${totalBalance.abs().toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                              color: totalBalance > 0
                                  ? Colors.green
                                  : totalBalance < 0
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalBalance > 0
                            ? "You are owed overall"
                            : totalBalance < 0
                            ? "You owe overall"
                            : "You are settled up",
                        style: TextStyle(
                          fontSize: 14,
                          color: totalBalance > 0
                              ? Colors.green
                              : totalBalance < 0
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tabs
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _tabButton("Overall", 0),
                    _tabButton("I Owe", 1),
                    _tabButton("Owed to Me", 2),
                  ],
                ),
                const SizedBox(height: 12),

                // Groups List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            selectedTab == 1
                                ? "No groups where you owe money"
                                : "No groups where you are owed money",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final group = filtered[index];
                            final balance = _groupService.getUserBalanceInGroup(
                              group,
                            );
                            final groupName =
                                group["groupName"] ?? "Unnamed Group";
                            final memberCount =
                                (group["members"] as List?)?.length ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: primary.withOpacity(0.1),
                                  child: Icon(
                                    Icons.group,
                                    color: primary,
                                    size: 28,
                                  ),
                                ),
                                title: Text(
                                  groupName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  "$memberCount members",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ), // slightly smaller
                                      decoration: BoxDecoration(
                                        color: balance > 0
                                            ? Colors.green.shade50
                                            : balance < 0
                                            ? Colors.red.shade50
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: balance > 0
                                              ? Colors.green.shade200
                                              : balance < 0
                                              ? Colors.red.shade200
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        "${balance >= 0 ? '+' : ''}₹${balance.abs().toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: balance > 0
                                              ? Colors.green.shade700
                                              : balance < 0
                                              ? Colors.red.shade700
                                              : Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2), // reduce spacing
                                    Text(
                                      balance > 0
                                          ? "you are owed"
                                          : balance < 0
                                          ? "you owe"
                                          : "settled up",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        height: 1.4,
                                        letterSpacing: 0.5,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),

                                onTap: () {
                                  // TODO: Navigate to group details
                                },
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
