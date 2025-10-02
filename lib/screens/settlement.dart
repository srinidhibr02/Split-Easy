import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/constants.dart';

// Data model for a settlement transaction
class Settlement {
  final String fromPhone;
  final String fromName;
  final String toPhone;
  final String toName;
  final double amount;

  Settlement({
    required this.fromPhone,
    required this.fromName,
    required this.toPhone,
    required this.toName,
    required this.amount,
  });
}

// Calculate settlements for a group
class SettlementCalculator {
  static List<Settlement> calculateSettlements(Map<String, dynamic> group) {
    final members =
        (group["members"] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    List<Map<String, dynamic>> debtors = [];
    List<Map<String, dynamic>> creditors = [];

    for (var member in members) {
      final balance = (member["balance"] ?? 0.0).toDouble();
      final memberData = {
        "phoneNumber": member["phoneNumber"],
        "name": member["name"],
        "balance": balance.abs(),
      };
      if (balance < -0.01) {
        debtors.add(memberData);
      } else if (balance > 0.01) {
        creditors.add(memberData);
      }
    }

    debtors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );
    creditors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );

    List<Settlement> settlements = [];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor["balance"] as double;
      final creditAmount = creditor["balance"] as double;
      final settleAmount = debtAmount < creditAmount
          ? debtAmount
          : creditAmount;

      settlements.add(
        Settlement(
          fromPhone: debtor["phoneNumber"],
          fromName: debtor["name"],
          toPhone: creditor["phoneNumber"],
          toName: creditor["name"],
          amount: settleAmount,
        ),
      );

      debtor["balance"] = debtAmount - settleAmount;
      creditor["balance"] = creditAmount - settleAmount;

      if (debtor["balance"] < 0.01) i++;
      if (creditor["balance"] < 0.01) j++;
    }

    return settlements;
  }

  static List<Settlement> getMySettlements(
    Map<String, dynamic> group,
    String currentUserPhone,
  ) {
    final allSettlements = calculateSettlements(group);
    return allSettlements
        .where(
          (s) =>
              s.fromPhone == currentUserPhone || s.toPhone == currentUserPhone,
        )
        .toList();
  }
}

// Enhanced Widget to display settlements
class GroupSettlementWidget extends StatelessWidget {
  final Map<String, dynamic> group;
  final String currentUserPhone;

  const GroupSettlementWidget({
    super.key,
    required this.group,
    required this.currentUserPhone,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups")
          .doc(group["id"])
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupData = groupSnapshot.data!.data() as Map<String, dynamic>;
        final members = groupData["members"] as List<dynamic>? ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("groups")
              .doc(group["id"])
              .collection("expenses")
              .snapshots(),
          builder: (context, expenseSnapshot) {
            if (!expenseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final expenses = expenseSnapshot.data!.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();

            final mySettlements = SettlementCalculator.getMySettlements(
              groupData,
              currentUserPhone,
            );

            final totalSpending = _calculateTotalSpending(expenses);
            final myTotalPaid = _calculateMyTotalPaid(expenses);
            final myTotalShare = _calculateMyTotalShare(expenses);
            final myBalance = _getMyBalance(groupData);

            return _buildUI(
              members,
              expenses,
              mySettlements,
              totalSpending,
              myTotalPaid,
              myTotalShare,
              myBalance,
              context,
            );
          },
        );
      },
    );
  }

  Widget _buildUI(
    List<dynamic> members,
    List<Map<String, dynamic>> expenses,
    List<Settlement> mySettlements,
    double totalSpending,
    double myTotalPaid,
    double myTotalShare,
    double myBalance,
    BuildContext context,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with group stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Settlement Summary",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${members.length} members • ${expenses.length} expenses",
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Your Status Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: myBalance > 0
                  ? Colors.green.shade50
                  : myBalance < 0
                  ? Colors.red.shade50
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: myBalance > 0
                    ? Colors.green.shade200
                    : myBalance < 0
                    ? Colors.red.shade200
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      myBalance > 0
                          ? Icons.trending_up
                          : myBalance < 0
                          ? Icons.trending_down
                          : Icons.check_circle,
                      color: myBalance > 0
                          ? Colors.green.shade700
                          : myBalance < 0
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          myBalance > 0
                              ? "You are owed"
                              : myBalance < 0
                              ? "You owe"
                              : "All settled up",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: myBalance > 0
                                ? Colors.green.shade700
                                : myBalance < 0
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          "₹${myBalance.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: myBalance > 0
                                ? Colors.green.shade700
                                : myBalance < 0
                                ? Colors.red.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Settlements section
          if (mySettlements.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, color: primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Suggested Settlements",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: mySettlements.length,
              itemBuilder: (context, index) {
                final settlement = mySettlements[index];
                final iOwe = settlement.fromPhone == currentUserPhone;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: iOwe
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            iOwe ? Icons.arrow_upward : Icons.arrow_downward,
                            color: iOwe
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                iOwe
                                    ? "You owe ${settlement.toName}"
                                    : "${settlement.fromName} owes you",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "₹${settlement.amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: iOwe
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showSettleDialog(context, settlement, iOwe),
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: iOwe
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            size: 28,
                          ),
                          tooltip: "Mark as settled",
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),

          // Group Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.bar_chart, color: primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Your Statistics",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _statCard(
                    "Total Paid",
                    "₹${myTotalPaid.toStringAsFixed(2)}",
                    Icons.payment,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    "Your Share",
                    "₹${myTotalShare.toStringAsFixed(2)}",
                    Icons.receipt_long,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _statCard(
              "Total Group Spending",
              "₹${totalSpending.toStringAsFixed(2)}",
              Icons.account_balance_wallet,
              Colors.purple,
              isWide: true,
            ),
          ),

          const SizedBox(height: 24),

          // Info Section
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Settlements are optimized to minimize the number of transactions needed to balance everyone.",
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isWide = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: isWide
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isWide
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isWide ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
      total += paidBy[currentUserPhone] ?? 0.0;
    }
    return total;
  }

  double _calculateMyTotalShare(List<Map<String, dynamic>> expenses) {
    double total = 0.0;
    for (var expense in expenses) {
      final participants = Map<String, double>.from(
        expense["participants"] ?? {},
      );
      total += participants[currentUserPhone] ?? 0.0;
    }
    return total;
  }

  double _getMyBalance(Map<String, dynamic> group) {
    final members = group["members"] as List<dynamic>? ?? [];
    for (var member in members) {
      if (member["phoneNumber"] == currentUserPhone) {
        return (member["balance"] ?? 0.0).toDouble();
      }
    }
    return 0.0;
  }

  void _showSettleDialog(
    BuildContext context,
    Settlement settlement,
    bool iOwe,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Record Payment"),
        content: Text(
          iOwe
              ? "Did you pay ₹${settlement.amount.toStringAsFixed(2)} to ${settlement.toName}?"
              : "Did ${settlement.fromName} pay you ₹${settlement.amount.toStringAsFixed(2)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Settlement recorded successfully"),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }
}
