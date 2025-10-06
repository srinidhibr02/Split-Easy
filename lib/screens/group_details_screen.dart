import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:split_easy/screens/settlement.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';
import 'package:split_easy/services/group_services.dart';
import 'package:split_easy/services/stream_operations.dart';
import 'package:split_easy/widgets/add_expense_dialog.dart';
import 'package:split_easy/widgets/add_member_dialog.dart';
import 'package:split_easy/widgets/member_selection_dialog.dart';
import '../constants.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirestoreServices firestoreServices = FirestoreServices();
  final GroupService groupService = GroupService();
  final AuthServices authServices = AuthServices();
  final StreamOperations streams = StreamOperations();

  @override
  Widget build(BuildContext context) {
    final groupId = widget.group["id"];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withAlpha((255 * 0.7).round())],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                color: white,
                getPurposeIcon(widget.group["purpose"]),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group["groupName"] ?? "Group",
                    style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.group["purpose"] ?? "",
                    style: TextStyle(
                      color: primary.withAlpha((255 * 0.7).round()),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Group Summary Card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("groups")
                .doc(groupId)
                .collection("expenses")
                .snapshots(),
            builder: (context, expenseSnapshot) {
              final expenseCount = expenseSnapshot.data?.docs.length ?? 0;
              final memberCount =
                  (widget.group["members"] as List?)?.length ?? 0;

              // Calculate total amount
              double totalAmount = 0;
              if (expenseSnapshot.hasData) {
                for (var doc in expenseSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalAmount += (data["amount"]?.toDouble() ?? 0);
                }
              }

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withAlpha((255 * 0.7).round()),
                      secondary.withAlpha((255 * 0.05).round()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withAlpha((255 * 0.2).round()),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _summaryItem(
                          Icons.people,
                          "$memberCount",
                          "Members",
                          Colors.blue,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        _summaryItem(
                          Icons.receipt_long,
                          "$expenseCount",
                          "Expenses",
                          Colors.orange,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        _summaryItem(
                          Icons.currency_rupee,
                          totalAmount.toStringAsFixed(0),
                          "Total Spent",
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _actionCard(
                    icon: Icons.person_add,
                    label: "Add Member",
                    color: Colors.blue,
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                  const SizedBox(width: 12),
                  _actionCard(
                    icon: Icons.attach_money,
                    label: "Add Expense",
                    color: Colors.green,
                    onPressed: () =>
                        _showAddExpenseDialog(context, widget.group),
                  ),

                  const SizedBox(width: 12),
                  _actionCard(
                    icon: Icons.group,
                    label: "View Members",
                    color: Colors.purple,
                    onPressed: () => _showMembersDialog(context, widget.group),
                  ),
                  const SizedBox(width: 12),
                  _actionCard(
                    icon: Icons.account_balance,
                    label: "Settlement",
                    color: Colors.orange,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text("Settlement"),
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                            body: GroupSettlementWidget(
                              group: widget.group,
                              currentUserPhone:
                                  authServices.currentUser!.phoneNumber
                                      as String,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.history, color: primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Recent Expenses",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const Spacer(),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("groups")
                      .doc(groupId)
                      .collection("expenses")
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$count total",
                        style: const TextStyle(
                          color: primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Expenses List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("groups")
                  .doc(groupId)
                  .collection("expenses")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No expenses yet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Add your first expense to get started!",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final expenses = snapshot.data!.docs;
                final members = (widget.group["members"] as List<dynamic>)
                    .map((e) => e as Map<String, dynamic>)
                    .toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expenseDoc = expenses[index];
                    final expense = expenseDoc.data() as Map<String, dynamic>;
                    final expenseId = expenseDoc.id;

                    final title = expense["title"] ?? "";
                    final amount = expense["amount"]?.toDouble() ?? 0;
                    final createdAt = expense["createdAt"];

                    // Get date
                    String getExpenseDate() {
                      if (createdAt == null) return "";
                      try {
                        final DateTime created = (createdAt as dynamic)
                            .toDate();
                        final now = DateTime.now();
                        final difference = now.difference(created);

                        if (difference.inDays == 0) {
                          return "Today";
                        } else if (difference.inDays == 1) {
                          return "Yesterday";
                        } else if (difference.inDays < 7) {
                          return "${difference.inDays} days ago";
                        } else {
                          return "${created.day}/${created.month}/${created.year}";
                        }
                      } catch (e) {
                        return "";
                      }
                    }

                    final paidByMap = Map<String, double>.from(
                      expense["paidBy"] ?? {},
                    );
                    final participantsMap = Map<String, double>.from(
                      expense["participants"] ?? {},
                    );

                    Widget buildMemberChips(
                      Map<String, double> memberAmounts,
                      Color chipColor,
                    ) {
                      if (memberAmounts.isEmpty) return const SizedBox.shrink();

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: memberAmounts.entries.map((entry) {
                          final phoneNumber = entry.key;
                          final memberAmount = entry.value;

                          final member = members.firstWhere(
                            (m) => m["phoneNumber"] == phoneNumber,
                            orElse: () => {"name": phoneNumber, "avatar": ""},
                          );

                          return Chip(
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  member["avatar"] != null &&
                                      member["avatar"] != ""
                                  ? NetworkImage(member["avatar"])
                                  : const AssetImage(
                                          "images/default_avatar.png",
                                        )
                                        as ImageProvider,
                            ),
                            label: Text(
                              "${member["name"] ?? "Unknown"} • ₹${memberAmount.toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: chipColor,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.all(16),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  getExpenseDate(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.people,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${participantsMap.length} people",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.green.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              "₹${amount.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          children: [
                            const Divider(),
                            const SizedBox(height: 8),

                            // Paid By Section
                            if (paidByMap.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      size: 18,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Paid By:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              buildMemberChips(paidByMap, Colors.green.shade50),
                              const SizedBox(height: 16),
                            ],

                            // Participants Section
                            if (participantsMap.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.people,
                                      size: 18,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Split Between:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              buildMemberChips(
                                participantsMap,
                                Colors.orange.shade50,
                              ),
                              const SizedBox(height: 16),
                            ],

                            const Divider(),
                            const SizedBox(height: 8),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _showEditExpenseDialog(
                                      context,
                                      expenseId,
                                      expense,
                                      widget.group,
                                    );
                                  },
                                  icon: const Icon(Icons.edit, size: 18),
                                  label: const Text("Edit"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    side: BorderSide(
                                      color: Colors.blue.shade300,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                            ),
                                            SizedBox(width: 8),
                                            Text("Delete Expense?"),
                                          ],
                                        ),
                                        content: Text(
                                          "Are you sure you want to delete '$title' expense?\n\nThis will reverse all balance changes.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        groupService.deleteExpenseWithActivity(
                                          groupId: groupId,
                                          expenseId: expenseId,
                                          expenseTitle: title,
                                          amount: amount,
                                          paidBy: paidByMap,
                                          participants: participantsMap,
                                        );

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Expense deleted successfully',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text("Delete"),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddExpenseDialog(context, widget.group);
        },
        backgroundColor: primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add), // 👈 use child, not key
      ),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color..withAlpha((255 * 0.1).round()),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.1).round()),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha((255 * 0.3).round())),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //Show Members Dialog
  void _showMembersDialog(BuildContext context, Map<String, dynamic> group) {
    final firestoreServices = FirestoreServices();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Group Members"),
        content: StreamBuilder(
          stream: streams.streamGroupById(group["id"]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupData = snapshot.data!;
            final members = List<Map<String, dynamic>>.from(
              groupData["members"] ?? [],
            );

            if (members.isEmpty) {
              return const Text("No members added yet.");
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final displayName = member["name"] ?? member["phoneNumber"];
                  final phone = member["phoneNumber"] ?? "Unknown";

                  return ListTile(
                    leading: member["avatar"] != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(member["avatar"]),
                          )
                        : const Icon(Icons.person),
                    title: Text(displayName),
                    subtitle: Text(phone),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // ✅ Add Member Dialog
  void _showAddMemberDialog(BuildContext context) {
    showAddMemberDialog(
      context,
      groupId: widget.group["id"],
      onAddMember: (phoneNumber) async {
        final whoAdded = authServices.currentUser?.phoneNumber;
        await firestoreServices.addMemberToGroup(
          groupId: widget.group["id"],
          newMemberPhoneNumber: phoneNumber,
          addedByPhoneNumber: whoAdded as String,
        );
      },
    );
  }

  // ✅ Add Expense Dialog
  void _showAddExpenseDialog(BuildContext context, Map<String, dynamic> group) {
    showAddExpenseDialog(
      context,
      group: group,
      streamGroupById: streams.streamGroupById,
      onAddExpense:
          ({
            required String groupId,
            required String title,
            required double amount,
            required Map<String, double> paidBy,
            required Map<String, double> participants,
          }) async {
            await groupService.addExpenseWithActivity(
              groupId: groupId,
              title: title,
              amount: amount,
              paidBy: paidBy,
              participants: participants,
            );
          },
    );
  }

  void _showEditExpenseDialog(
    BuildContext context,
    String expenseId,
    Map<String, dynamic> expense,
    Map<String, dynamic> group,
  ) {
    final titleController = TextEditingController(text: expense["title"] ?? "");
    final amountController = TextEditingController(
      text: expense["amount"]?.toString() ?? "",
    );

    // Store old values for balance reversal
    Map<String, double> oldPaidBy = Map<String, double>.from(
      expense["paidBy"] ?? {},
    );
    Map<String, double> oldParticipants = Map<String, double>.from(
      expense["participants"] ?? {},
    );

    // Current selected values
    Map<String, double> selectedPayers = Map<String, double>.from(oldPaidBy);
    Map<String, double> selectedParticipants = Map<String, double>.from(
      oldParticipants,
    );

    final members = (group["members"] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // Track the last known amount to detect changes
    double lastAmount = expense["amount"]?.toDouble() ?? 0;

    void recalculateShares(StateSetter setState, double newAmount) {
      if (newAmount <= 0) return;

      // Recalculate payers proportionally
      if (selectedPayers.isNotEmpty) {
        double oldTotal = selectedPayers.values.fold(
          0,
          // ignore: avoid_types_as_parameter_names
          (sum, val) => sum + val,
        );
        if (oldTotal > 0) {
          Map<String, double> newPayers = {};
          selectedPayers.forEach((phone, oldAmount) {
            double proportion = oldAmount / oldTotal;
            newPayers[phone] = newAmount * proportion;
          });
          setState(() {
            selectedPayers = newPayers;
          });
        }
      }

      // Recalculate participants proportionally
      if (selectedParticipants.isNotEmpty) {
        double oldTotal = selectedParticipants.values.fold(
          0,
          // ignore: avoid_types_as_parameter_names
          (sum, val) => sum + val,
        );
        if (oldTotal > 0) {
          Map<String, double> newParticipants = {};
          selectedParticipants.forEach((phone, oldAmount) {
            double proportion = oldAmount / oldTotal;
            newParticipants[phone] = newAmount * proportion;
          });
          setState(() {
            selectedParticipants = newParticipants;
          });
        }
      }

      lastAmount = newAmount;
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          // Check if amount changed and recalculate
          double currentAmount =
              double.tryParse(amountController.text.trim()) ?? 0;
          if (currentAmount > 0 && (currentAmount - lastAmount).abs() > 0.01) {
            // Schedule recalculation after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              recalculateShares(setState, currentAmount);
            });
          }

          return AlertDialog(
            title: const Text("Edit Expense"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Expense Title",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: "Amount",
                      prefixText: "₹ ",
                      border: OutlineInputBorder(),
                      helperText: "Changes will auto-update splits",
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      double newAmount = double.tryParse(value.trim()) ?? 0;
                      if (newAmount > 0 &&
                          (newAmount - lastAmount).abs() > 0.01) {
                        recalculateShares(setState, newAmount);
                      }
                    },
                  ),
                  const SizedBox(height: 15),

                  // Payers Section
                  InkWell(
                    onTap: () async {
                      double expAmount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      final result = await showDialog(
                        context: context,
                        builder: (_) => MemberSelectionDialog(
                          members: members,
                          amount: expAmount,
                          initialSelected: selectedPayers,
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          selectedPayers = Map<String, double>.from(result);
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Select Payers",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        selectedPayers.isEmpty
                            ? "Tap to select payers"
                            : "${selectedPayers.length} payer(s) selected",
                        style: TextStyle(
                          color: selectedPayers.isEmpty
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  // Display selected payers
                  if (selectedPayers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Selected Payers:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...selectedPayers.entries.map((entry) {
                            final member = members.firstWhere(
                              (m) => m["phoneNumber"] == entry.key,
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      member["name"],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    "₹${entry.value.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),

                  // Participants Section
                  InkWell(
                    onTap: () async {
                      double expAmount =
                          double.tryParse(amountController.text.trim()) ?? 0;
                      final result = await showDialog(
                        context: context,
                        builder: (_) => MemberSelectionDialog(
                          amount: expAmount,
                          members: members,
                          initialSelected: selectedParticipants,
                        ),
                      );

                      if (result != null) {
                        setState(() {
                          selectedParticipants = Map<String, double>.from(
                            result,
                          );
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "Select Participants",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: Text(
                        selectedParticipants.isEmpty
                            ? "Tap to select participants"
                            : "${selectedParticipants.length} participant(s) selected",
                        style: TextStyle(
                          color: selectedParticipants.isEmpty
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  // Display selected participants
                  if (selectedParticipants.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Selected Participants:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...selectedParticipants.entries.map((entry) {
                            final member = members.firstWhere(
                              (m) => m["phoneNumber"] == entry.key,
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      member["name"],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    "₹${entry.value.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 15),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final expenseTitle = titleController.text.trim();
                  final expenseAmount =
                      double.tryParse(amountController.text.trim()) ?? 0;

                  if (expenseTitle.isEmpty ||
                      expenseAmount <= 0 ||
                      selectedPayers.isEmpty ||
                      selectedParticipants.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill all fields'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    // Call Firestore service to edit expense
                    await groupService.editExpenseWithActivity(
                      groupId: group["id"],
                      expenseId: expenseId,
                      title: expenseTitle,
                      amount: expenseAmount,
                      paidBy: selectedPayers,
                      participants: selectedParticipants,
                      oldPaidBy: oldPaidBy,
                      oldParticipants: oldParticipants,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Expense updated successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Update Expense"),
              ),
            ],
          );
        },
      ),
    );
  }
}
