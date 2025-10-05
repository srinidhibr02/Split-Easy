import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/dataModels/dataModels.dart';
import 'package:split_easy/services/settlement_service.dart';

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
class GroupSettlementWidget extends StatefulWidget {
  final Map<String, dynamic> group;
  final String currentUserPhone;
  final Function? onSettlementRecorded;

  const GroupSettlementWidget({
    super.key,
    required this.group,
    required this.currentUserPhone,
    this.onSettlementRecorded,
  });

  @override
  State<GroupSettlementWidget> createState() => _GroupSettlementWidgetState();
}

class _GroupSettlementWidgetState extends State<GroupSettlementWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _settlementService = SettlementService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groups")
          .doc(widget.group["id"])
          .snapshots(),
      builder: (context, groupSnapshot) {
        if (!groupSnapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: primary),
                const SizedBox(height: 16),
                Text(
                  "Loading settlements...",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final groupDoc = groupSnapshot.data;
        if (groupDoc == null || !groupDoc.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  "Group not found",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          );
        }

        final groupData = groupDoc.data() as Map<String, dynamic>;
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

            final mySettlements = SettlementCalculator.getMySettlements(
              groupData,
              widget.currentUserPhone,
            );

            final totalSpending = _calculateTotalSpending(expenses);
            final myTotalPaid = _calculateMyTotalPaid(expenses);
            final myTotalShare = _calculateMyTotalShare(expenses);
            final myBalance = _getMyBalance(groupData);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildUI(
                members,
                expenses,
                mySettlements,
                totalSpending,
                myTotalPaid,
                myTotalShare,
                myBalance,
                context,
              ),
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
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withAlpha((255 * 0.8).round())],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withAlpha((255 * 0.3).round()),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((255 * 0.2).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Settlement Summary",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Track and settle your expenses",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha((255 * 0.15).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat(
                        "${members.length}",
                        "Members",
                        Icons.people,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withAlpha((255 * 0.3).round()),
                      ),
                      _buildHeaderStat(
                        "${expenses.length}",
                        "Expenses",
                        Icons.receipt_long,
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withAlpha((255 * 0.3).round()),
                      ),
                      _buildHeaderStat(
                        "₹${totalSpending.toStringAsFixed(0)}",
                        "Total",
                        Icons.currency_rupee,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Your Balance Card with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: myBalance > 0
                    ? [Colors.green.shade50, Colors.green.shade100]
                    : myBalance < 0
                    ? [Colors.red.shade50, Colors.red.shade100]
                    : [Colors.grey.shade50, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: myBalance > 0
                    ? Colors.green.shade300
                    : myBalance < 0
                    ? Colors.red.shade300
                    : Colors.grey.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (myBalance > 0
                              ? Colors.green
                              : myBalance < 0
                              ? Colors.red
                              : Colors.grey)
                          .withAlpha((255 * 0.2).round()),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.1).round()),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
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
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  myBalance > 0
                      ? "You are owed"
                      : myBalance < 0
                      ? "You owe"
                      : "All settled up!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: myBalance > 0
                        ? Colors.green.shade900
                        : myBalance < 0
                        ? Colors.red.shade900
                        : Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "₹${myBalance.abs().toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: myBalance > 0
                        ? Colors.green.shade700
                        : myBalance < 0
                        ? Colors.red.shade700
                        : Colors.grey.shade700,
                    letterSpacing: -1,
                  ),
                ),
                if (myBalance == 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.celebration,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "You're all caught up",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Settlements section
          if (mySettlements.isEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No settlements needed",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You're all settled up with everyone!",
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.swap_horiz, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Suggested Settlements",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${mySettlements.length}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: mySettlements.length,
              itemBuilder: (context, index) {
                final settlement = mySettlements[index];
                final iOwe = settlement.fromPhone == widget.currentUserPhone;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: iOwe
                          ? [Colors.red.shade50, Colors.red.shade100]
                          : [Colors.green.shade50, Colors.green.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: iOwe ? Colors.red.shade200 : Colors.green.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showSettleDialog(context, settlement, iOwe),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (255 * 0.1).round(),
                                    ),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                iOwe
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
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
                                    iOwe ? "You owe" : "Owes you",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: iOwe
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    iOwe
                                        ? settlement.toName
                                        : settlement.fromName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "₹${settlement.amount.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: iOwe
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(
                                      (255 * 0.05).round(),
                                    ),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios,
                                color: iOwe
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 32),

          // Group Statistics
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bar_chart, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
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
          const SizedBox(height: 16),

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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
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

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha((255 * 0.1).round()),
            color.withAlpha((255 * 0.15).round()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((255 * 0.3).round())),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha((255 * 0.2).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isWide ? 28 : 22,
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

  void _showSettleDialog(
    BuildContext context,
    Settlement settlement,
    bool iOwe,
  ) {
    showDialog<bool>(
      context: context,
      builder: (_) => RecordSettlementDialog(
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

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text("Settlement recorded successfully!"),
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

            Navigator.of(context).pop(true);
          } catch (e) {
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Failed to record settlement: ${e.toString()}",
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );

            Navigator.of(context).pop(false);
          }
        },
      ),
    );
  }
}

// Enhanced Settlement Dialog
class RecordSettlementDialog extends StatefulWidget {
  final Settlement settlement;
  final bool iOwe;
  final Future<void> Function() onConfirm;

  const RecordSettlementDialog({
    super.key,
    required this.settlement,
    required this.iOwe,
    required this.onConfirm,
  });

  @override
  State<RecordSettlementDialog> createState() => _RecordSettlementDialogState();
}

class _RecordSettlementDialogState extends State<RecordSettlementDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await widget.onConfirm();

    if (!mounted) return;

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [Colors.white, Colors.grey.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.iOwe
                        ? [Colors.red.shade400, Colors.red.shade700]
                        : [Colors.green.shade400, Colors.green.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      child: Icon(
                        widget.iOwe
                            ? Icons.payment
                            : Icons.account_balance_wallet,
                        size: 36,
                        color: widget.iOwe
                            ? Colors.red.shade600
                            : Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Record Settlement",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.iOwe ? "Confirm Payment" : "Confirm Receipt",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((255 * 0.05).round()),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            "From",
                            widget.iOwe ? "You" : widget.settlement.fromName,
                            Icons.person,
                          ),
                          const SizedBox(height: 12),
                          Icon(
                            Icons.swap_vert_rounded,
                            color: Colors.grey.shade400,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow(
                            "To",
                            widget.iOwe ? widget.settlement.toName : "You",
                            Icons.person_outline,
                          ),
                          const Divider(height: 32),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: "Amount: ",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      "₹${widget.settlement.amount.toStringAsFixed(2)}",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: widget.iOwe
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.iOwe
                            ? Colors.red.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.iOwe
                              ? Colors.red.shade200
                              : Colors.green.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: widget.iOwe
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.iOwe
                                  ? "Confirm that you have paid this amount"
                                  : "Confirm that you have received this amount",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: widget.iOwe
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          backgroundColor: widget.iOwe
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Confirm",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
