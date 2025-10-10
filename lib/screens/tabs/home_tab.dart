import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/screens/settlement.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/widgets/friend_balance.dart';
import 'package:split_easy/services/group_services.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final GroupService _groupService = GroupService();
  final AuthServices _authServices = AuthServices();
  final FriendsBalanceService _friendsBalanceService = FriendsBalanceService();

  int selectedTab = 0;
  bool hasInitializedBalances = false;

  @override
  Widget build(BuildContext context) {
    final userPhone = _authServices.currentUser?.phoneNumber ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _groupService.getUserGroupsStream(),
        builder: (context, groupsSnapshot) {
          if (groupsSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primary),
                  const SizedBox(height: 16),
                  Text(
                    "Loading your groups...",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final groups = groupsSnapshot.data ?? [];

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
          final totalOwed = groups.fold<double>(
            0.0,
            (sum, group) =>
                sum +
                (_groupService.getMyBalance(group) > 0
                    ? _groupService.getMyBalance(group)
                    : 0),
          );
          final totalOwe = groups.fold<double>(
            0.0,
            (sum, group) =>
                sum +
                (_groupService.getMyBalance(group) < 0
                    ? _groupService.getMyBalance(group).abs()
                    : 0),
          );

          final filtered = groups.where((group) {
            final balance = _groupService.getUserBalanceInGroup(group);
            if (selectedTab == 1) return balance < 0;
            if (selectedTab == 2) return balance > 0;
            return true;
          }).toList();

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // --- Summary Section ---
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primary.withAlpha((255 * 0.15).round()),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((255 * 0.03).round()),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Overall Balance",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withAlpha((255 * 0.1).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${groups.length} Groups",
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Balance
                        Row(
                          children: [
                            Text(
                              totalBalance >= 0 ? "+" : "",
                              style: TextStyle(
                                fontSize: 36,
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
                                fontSize: 36,
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
                            fontSize: 13,
                            color: totalBalance > 0
                                ? Colors.green.shade700
                                : totalBalance < 0
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Compact Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                "You'll Get",
                                "₹${totalOwed.toStringAsFixed(2)}",
                                Icons.arrow_downward,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                "You Owe",
                                "₹${totalOwe.toStringAsFixed(2)}",
                                Icons.arrow_upward,
                                Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Friend Balances ---
                SliverToBoxAdapter(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _friendsBalanceService.streamFriendsWithBalances(
                      userPhone: userPhone,
                    ),
                    builder: (context, friendsSnapshot) {
                      if (friendsSnapshot.hasData &&
                          friendsSnapshot.data!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: FriendsBalanceWidget(
                            friends: friendsSnapshot.data!,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

                // --- Tabs ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _tabButton("Overall", 0, groups.length),
                        _tabButton(
                          "I Owe",
                          1,
                          groups
                              .where(
                                (g) =>
                                    _groupService.getUserBalanceInGroup(g) < 0,
                              )
                              .length,
                        ),
                        _tabButton(
                          "Owed to Me",
                          2,
                          groups
                              .where(
                                (g) =>
                                    _groupService.getUserBalanceInGroup(g) > 0,
                              )
                              .length,
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Groups List ---
                filtered.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            "No groups found for this view",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final group = filtered[index];
                          final balance = _groupService.getUserBalanceInGroup(
                            group,
                          );
                          final groupName =
                              group["groupName"] ?? "Unnamed Group";
                          final memberCount =
                              (group["members"] as List?)?.length ?? 0;

                          return _buildGroupCard(
                            context,
                            group,
                            groupName,
                            balance,
                            memberCount,
                          );
                        }, childCount: filtered.length),
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- Widgets ---------------- //

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.08).round()),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha((255 * 0.25).round())),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String text, int index, int count) {
    final isSelected = selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha((255 * 0.3).round())
                      : primary.withAlpha((255 * 0.15).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    Map<String, dynamic> group,
    String groupName,
    double balance,
    int memberCount,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text(
                    groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                body: ModernSettlementScreen(
                  group: group,
                  currentUserPhone:
                      _authServices.currentUser?.phoneNumber as String,
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.group, color: primary, size: 24),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$memberCount members",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${balance >= 0 ? '+' : '-'}₹${balance.abs().toStringAsFixed(0)}",
                    style: TextStyle(
                      color: balance > 0
                          ? Colors.green
                          : balance < 0
                          ? Colors.red
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    balance > 0
                        ? "you are owed"
                        : balance < 0
                        ? "you owe"
                        : "settled",
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
