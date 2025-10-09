import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/dataModels/dataModels.dart';
import 'package:split_easy/services/settlement_calculator.dart';
import 'package:split_easy/services/settlement_service.dart';

class ModernSettlementScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final String currentUserPhone;
  final Function? onSettlementRecorded;

  const ModernSettlementScreen({
    super.key,
    required this.group,
    required this.currentUserPhone,
    this.onSettlementRecorded,
  });

  @override
  State<ModernSettlementScreen> createState() => _ModernSettlementScreenState();
}

class _ModernSettlementScreenState extends State<ModernSettlementScreen> {
  final _settlementService = SettlementService();
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("groups")
            .doc(widget.group["id"])
            .snapshots(),
        builder: (context, groupSnapshot) {
          if (!groupSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primary));
          }

          final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
          final members = groupData["members"] as List<dynamic>? ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("groups")
                .doc(widget.group["id"])
                .collection("expenses")
                .snapshots(),
            builder: (context, expenseSnapshot) {
              if (!expenseSnapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: primary));
              }

              final expenses = expenseSnapshot.data!.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();

              final myBalance = _getMyBalance(groupData);
              final settlements = SettlementCalculator.getMySettlements(
                groupData,
                widget.currentUserPhone,
              );
              final totalSpending = _calculateTotalSpending(expenses);
              final myTotalPaid = _calculateMyTotalPaid(expenses);
              final myTotalShare = _calculateMyTotalShare(expenses);

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    automaticallyImplyLeading:
                        false, // 🚫 removes default back button
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: primary,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primary, primary.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  myBalance > 0
                                      ? "You'll get back"
                                      : myBalance < 0
                                      ? "You owe in total"
                                      : "All Settled!",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "₹",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      myBalance.abs().toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "${members.length} members • ${settlements.length} settlements",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              label: "Settlements",
                              icon: Icons.swap_horiz,
                              isSelected: _selectedTab == 0,
                              onTap: () => setState(() => _selectedTab = 0),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: "Members",
                              icon: Icons.people_outline,
                              isSelected: _selectedTab == 1,
                              onTap: () => setState(() => _selectedTab = 1),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: "Stats",
                              icon: Icons.bar_chart,
                              isSelected: _selectedTab == 2,
                              onTap: () => setState(() => _selectedTab = 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedTab == 0)
                    _buildSettlementsView(settlements, members)
                  else if (_selectedTab == 1)
                    _buildMembersView(members)
                  else
                    _buildStatsView(
                      totalSpending,
                      myTotalPaid,
                      myTotalShare,
                      expenses.length,
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSettlementsView(
    List<Settlement> settlements,
    List<dynamic> members,
  ) {
    if (settlements.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.celebration,
                  size: 64,
                  color: Colors.green[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "All Settled Up!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "No pending settlements",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final settlement = settlements[index];
          final iOwe = settlement.fromPhone == widget.currentUserPhone;
          final targetMember = members.firstWhere(
            (m) =>
                m["phoneNumber"] ==
                (iOwe ? settlement.toPhone : settlement.fromPhone),
            orElse: () => {
              "name": iOwe ? settlement.toName : settlement.fromName,
              "avatar": null,
            },
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showSettleDialog(settlement, iOwe),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient:
                              (targetMember["avatar"] == null ||
                                  targetMember["avatar"] == "" ||
                                  targetMember["avatar"] == "default_avatar")
                              ? LinearGradient(
                                  colors: iOwe
                                      ? [Colors.red[300]!, Colors.red[400]!]
                                      : [
                                          Colors.green[300]!,
                                          Colors.green[400]!,
                                        ],
                                )
                              : null,
                          shape: BoxShape.circle,
                          image:
                              (targetMember["avatar"] != null &&
                                  targetMember["avatar"] != "" &&
                                  targetMember["avatar"] != "default_avatar")
                              ? DecorationImage(
                                  image: NetworkImage(targetMember["avatar"]),
                                  fit: BoxFit.cover,
                                )
                              : const DecorationImage(
                                  image: AssetImage(
                                    'images/default_avatar.png',
                                  ),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),

                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              iOwe ? settlement.toName : settlement.fromName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  iOwe
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 14,
                                  color: iOwe
                                      ? Colors.red[600]
                                      : Colors.green[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  iOwe ? "You pay" : "You receive",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${settlement.amount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: iOwe ? Colors.red[600] : Colors.green[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (iOwe ? Colors.red : Colors.green)[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Settle",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: iOwe
                                    ? Colors.red[700]
                                    : Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }, childCount: settlements.length),
      ),
    );
  }

  Widget _buildMembersView(List<dynamic> members) {
    // Calculate all settlements for the group
    final allSettlements = SettlementCalculator.calculateSettlements({
      "members": members,
    });

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final member = members[index];
          final balance = (member["balance"] ?? 0.0).toDouble();
          final isMe = member["phoneNumber"] == widget.currentUserPhone;
          final hasAvatar =
              member["avatar"] != null &&
              member["avatar"] != "" &&
              member["avatar"] != "default_avatar";
          final memberPhone = member["phoneNumber"] as String;

          // Find settlements related to this member
          final memberOwes = allSettlements
              .where((s) => s.fromPhone == memberPhone)
              .toList();
          final memberGetsBack = allSettlements
              .where((s) => s.toPhone == memberPhone)
              .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMe ? primary.withOpacity(0.3) : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.all(16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasAvatar
                        ? null
                        : isMe
                        ? primary.withOpacity(0.1)
                        : Colors.grey[100],
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image:
                          (member["avatar"] != null &&
                              member["avatar"] != "" &&
                              member["avatar"] != "default_avatar")
                          ? NetworkImage(member["avatar"])
                          : const AssetImage('images/default_avatar.png')
                                as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        member["name"],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isMe)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "You",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        balance == 0
                            ? Icons.check_circle
                            : balance > 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: balance == 0
                            ? Colors.grey[600]
                            : balance > 0
                            ? Colors.green[600]
                            : Colors.red[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          balance == 0
                              ? "Settled up"
                              : balance > 0
                              ? "Gets back ₹${balance.toStringAsFixed(2)}"
                              : "Owes ₹${balance.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: balance == 0
                                ? Colors.grey[600]
                                : balance > 0
                                ? Colors.green[600]
                                : Colors.red[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                ),
                children: [
                  if (memberOwes.isEmpty && memberGetsBack.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.celebration,
                            color: Colors.green[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "All settled up!",
                            style: TextStyle(
                              color: Colors.green[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Owes section
                    if (memberOwes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward,
                                    color: Colors.red[700],
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isMe ? "You owe:" : "${member["name"]} owes:",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...memberOwes.map((settlement) {
                              final toMember = members.firstWhere(
                                (m) => m["phoneNumber"] == settlement.toPhone,
                                orElse: () => {"name": settlement.toName},
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward,
                                      size: 14,
                                      color: Colors.red[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        toMember["name"],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "₹${settlement.amount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Gets back section
                    if (memberGetsBack.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    color: Colors.green[700],
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isMe
                                      ? "You get back:"
                                      : "${member["name"]} gets back:",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...memberGetsBack.map((settlement) {
                              final fromMember = members.firstWhere(
                                (m) => m["phoneNumber"] == settlement.fromPhone,
                                orElse: () => {"name": settlement.fromName},
                              );
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_back,
                                      size: 14,
                                      color: Colors.green[600],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        fromMember["name"],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "₹${settlement.amount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        }, childCount: members.length),
      ),
    );
  }

  Widget _buildStatsView(
    double totalSpending,
    double myTotalPaid,
    double myTotalShare,
    int expenseCount,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withOpacity(0.1), primary.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person, color: primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Your Stats",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: "You Paid",
                        value: "₹${myTotalPaid.toStringAsFixed(2)}",
                        icon: Icons.payment,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatItem(
                        label: "Your Share",
                        value: "₹${myTotalShare.toStringAsFixed(2)}",
                        icon: Icons.receipt,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.groups, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Group Stats",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StatRow(
                  icon: Icons.account_balance_wallet,
                  label: "Total Spending",
                  value: "₹${totalSpending.toStringAsFixed(2)}",
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                _StatRow(
                  icon: Icons.receipt_long,
                  label: "Total Expenses",
                  value: "$expenseCount",
                  color: Colors.teal,
                ),
                const SizedBox(height: 16),
                _StatRow(
                  icon: Icons.analytics,
                  label: "Avg per Expense",
                  value: expenseCount > 0
                      ? "₹${(totalSpending / expenseCount).toStringAsFixed(2)}"
                      : "₹0.00",
                  color: Colors.indigo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.pie_chart,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Your Contribution",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (totalSpending > 0) ...[
                  _ProgressBar(
                    label: "Your share of total",
                    value: myTotalShare,
                    total: totalSpending,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _ProgressBar(
                    label: "Your payment of total",
                    value: myTotalPaid,
                    total: totalSpending,
                    color: Colors.blue,
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "No expenses yet",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  double _calculateTotalSpending(List<Map<String, dynamic>> expenses) {
    return expenses.fold(
      0.0,
      (sum, e) => sum + ((e["amount"] ?? 0) as num).toDouble(),
    );
  }

  double _calculateMyTotalPaid(List<Map<String, dynamic>> expenses) {
    double total = 0.0;
    for (var expense in expenses) {
      final paidBy = Map<String, double>.from(expense["paidBy"] ?? {});
      total += paidBy[widget.currentUserPhone] ?? 0.0;
    }
    return total;
  }

  double _calculateMyTotalShare(List<Map<String, dynamic>> expenses) {
    double total = 0.0;
    for (var expense in expenses) {
      final participants = Map<String, double>.from(
        expense["participants"] ?? {},
      );
      total += participants[widget.currentUserPhone] ?? 0.0;
    }
    return total;
  }

  double _getMyBalance(Map<String, dynamic> group) {
    final members = group["members"] as List<dynamic>? ?? [];
    for (var member in members) {
      if (member["phoneNumber"] == widget.currentUserPhone) {
        return (member["balance"] ?? 0.0).toDouble();
      }
    }
    return 0.0;
  }

  void _showSettleDialog(Settlement settlement, bool iOwe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModernSettleBottomSheet(
        settlement: settlement,
        iOwe: iOwe,
        onConfirm: () async {
          try {
            await _settlementService.recordSettlement(
              groupId: widget.group["id"],
              fromPhone: settlement.fromPhone,
              toPhone: settlement.toPhone,
              amount: settlement.amount,
              fromName: settlement.fromName,
              toName: settlement.toName,
            );
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text("Settlement recorded!"),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            widget.onSettlementRecorded?.call();
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? primary : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (value / total * 100) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              "${percentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "₹${value.toStringAsFixed(2)} of ₹${total.toStringAsFixed(2)}",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class ModernSettleBottomSheet extends StatefulWidget {
  final Settlement settlement;
  final bool iOwe;
  final Future<void> Function() onConfirm;

  const ModernSettleBottomSheet({
    super.key,
    required this.settlement,
    required this.iOwe,
    required this.onConfirm,
  });

  @override
  State<ModernSettleBottomSheet> createState() =>
      _ModernSettleBottomSheetState();
}

class _ModernSettleBottomSheetState extends State<ModernSettleBottomSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.iOwe
                        ? [Colors.red[50]!, Colors.red[100]!]
                        : [Colors.green[50]!, Colors.green[100]!],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.iOwe ? Icons.payment : Icons.account_balance_wallet,
                  size: 48,
                  color: widget.iOwe ? Colors.red[600] : Colors.green[600],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.iOwe ? "Confirm Payment" : "Confirm Receipt",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.iOwe
                    ? "to ${widget.settlement.toName}"
                    : "from ${widget.settlement.fromName}",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Text(
                "₹${widget.settlement.amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: widget.iOwe ? Colors.red[600] : Colors.green[600],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          await widget.onConfirm();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.iOwe
                        ? Colors.red[600]
                        : Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Confirm Settlement",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
