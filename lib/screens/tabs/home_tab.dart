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

          // Initialize balances calculation on first load
          if (groups.isNotEmpty &&
              userPhone.isNotEmpty &&
              !hasInitializedBalances) {
            hasInitializedBalances = true;
            // Trigger background recalculation
            Future.microtask(() {
              _friendsBalanceService.recalculateUserFriendBalances(
                userPhone: userPhone,
                groups: groups,
              );
            });
          }

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

          final totalOwed = groups.fold<double>(0.0, (sum, group) {
            final balance = _groupService.getMyBalance(group);
            return sum + (balance > 0 ? balance : 0);
          });

          final totalOwe = groups.fold<double>(0.0, (sum, group) {
            final balance = _groupService.getMyBalance(group);
            return sum + (balance < 0 ? balance.abs() : 0);
          });

          final filtered = groups.where((group) {
            final balance = _groupService.getUserBalanceInGroup(group);
            if (selectedTab == 1) return balance < 0;
            if (selectedTab == 2) return balance > 0;
            return true;
          }).toList();

          return SafeArea(
            child: CustomScrollView(
              slivers: [
                // Summary Section
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withOpacity(0.1),
                          secondary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Overall Balance",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                "${groups.length} Groups",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Balance Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              totalBalance >= 0 ? "+" : "",
                              style: TextStyle(
                                fontSize: 42,
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
                                fontSize: 42,
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

                        // Status Text
                        Text(
                          totalBalance > 0
                              ? "You are owed overall"
                              : totalBalance < 0
                              ? "You owe overall"
                              : "You are settled up",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: totalBalance > 0
                                ? Colors.green.shade700
                                : totalBalance < 0
                                ? Colors.red.shade700
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: _statCard(
                                "You'll Get",
                                "₹${totalOwed.toStringAsFixed(2)}",
                                Icons.arrow_downward,
                                Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
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

                // Friends Balance Section with Real-time Stream
                SliverToBoxAdapter(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _friendsBalanceService.streamFriendsWithBalances(
                      userPhone: userPhone,
                    ),
                    builder: (context, friendsSnapshot) {
                      if (friendsSnapshot.hasData &&
                          friendsSnapshot.data!.isNotEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FriendsBalanceWidget(
                            friends: friendsSnapshot.data!,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

                // Tabs
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _tabButton("Overall", 0, groups.length),
                          _tabButton(
                            "I Owe",
                            1,
                            groups
                                .where(
                                  (g) =>
                                      _groupService.getUserBalanceInGroup(g) <
                                      0,
                                )
                                .length,
                          ),
                          _tabButton(
                            "Owed to Me",
                            2,
                            groups
                                .where(
                                  (g) =>
                                      _groupService.getUserBalanceInGroup(g) >
                                      0,
                                )
                                .length,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Groups List
                filtered.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selectedTab == 1
                                    ? Icons.wallet
                                    : Icons.account_balance_wallet,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                selectedTab == 1
                                    ? "No groups where you owe money"
                                    : "No groups where you are owed money",
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
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
                          final expensesCount =
                              (group["expenses"] as List?)?.length ?? 0;

                          return _buildGroupCard(
                            context,
                            group,
                            groupName,
                            balance,
                            memberCount,
                            expensesCount,
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
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
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
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    color: isSelected ? Colors.white : primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
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
    int expensesCount,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..shader =
                            LinearGradient(
                              colors: <Color>[secondary, primary],
                            ).createShader(
                              const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                            ),
                    ),
                  ),
                ),
                body: GroupSettlementWidget(
                  group: group,
                  currentUserPhone:
                      _authServices.currentUser?.phoneNumber as String,
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Group Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withOpacity(0.2),
                      secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.group, color: primary, size: 28),
              ),
              const SizedBox(width: 16),

              // Group Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "$memberCount members",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (expensesCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.receipt,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$expensesCount expenses",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Balance Info
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance > 0
                        ? "you are owed"
                        : balance < 0
                        ? "you owe"
                        : "settled up",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
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
