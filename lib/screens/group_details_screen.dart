import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:split_easy/screens/settlement.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/expense_service.dart';
import 'package:split_easy/services/firestore_services.dart';
import 'package:split_easy/services/group_services.dart';
import 'package:split_easy/services/stream_operations.dart';
import 'package:split_easy/widgets/add_expense_dialog.dart';
import 'package:split_easy/widgets/add_member_dialog.dart';
import 'package:split_easy/widgets/edit_expense_dialog.dart';
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
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withAlpha((255 * 0.7).round())],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                color: white,
                getPurposeIcon(widget.group["purpose"]),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.group["groupName"] ?? "Group",
                    style: const TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.group["purpose"] ?? "",
                    style: TextStyle(
                      color: primary.withAlpha((255 * 0.7).round()),
                      fontSize: 11,
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
          // Compact Summary Card
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

              double totalAmount = 0;
              if (expenseSnapshot.hasData) {
                for (var doc in expenseSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  totalAmount += (data["amount"]?.toDouble() ?? 0);
                }
              }

              Widget _verticalDivider() =>
                  Container(width: 1, height: 35, color: Colors.grey.shade300);

              Widget _compactSummaryItem(
                IconData icon,
                String value,
                String label,
                Color color,
              ) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color.withOpacity(0.9), size: 26),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: secondary.withAlpha((255 * 0.25).round()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.05).round()),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _compactSummaryItem(
                      Icons.people,
                      "$memberCount",
                      "Members",
                      Colors.indigoAccent,
                    ),
                    _verticalDivider(),
                    _compactSummaryItem(
                      Icons.receipt_long,
                      "$expenseCount",
                      "Expenses",
                      Colors.teal,
                    ),
                    _verticalDivider(),
                    _compactSummaryItem(
                      Icons.currency_rupee,
                      totalAmount.toStringAsFixed(0),
                      "Total",
                      Colors.deepOrangeAccent,
                    ),
                  ],
                ),
              );
            },
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.person_add_alt_1,
                    label: "Add-Member",
                    color: Colors.blue,
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.add_circle_outline,
                    label: "Expense",
                    color: Colors.green,
                    onPressed: () =>
                        _showAddExpenseDialog(context, widget.group),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.groups_2,
                    label: "Members",
                    color: Colors.purple,
                    onPressed: () => _showMembersDialog(context, widget.group),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionButton(
                    icon: Icons.payments_outlined,
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
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Compact Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                const Icon(Icons.history, color: primary, size: 18),
                const SizedBox(width: 6),
                const Text(
                  "Recent Expenses",
                  style: TextStyle(
                    fontSize: 16,
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
                    return Text(
                      "$count total",
                      style: const TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Compact Expenses List
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
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "No expenses yet",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Add your first expense!",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expenseDoc = expenses[index];
                    final expense = expenseDoc.data() as Map<String, dynamic>;
                    final expenseId = expenseDoc.id;

                    final title = expense["title"] ?? "";
                    final amount = expense["amount"]?.toDouble() ?? 0;
                    final createdAt = expense["createdAt"];

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
                          return "${difference.inDays}d ago";
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

                    Widget buildCompactMemberChips(
                      Map<String, double> memberAmounts,
                      Color chipColor,
                    ) {
                      if (memberAmounts.isEmpty) return const SizedBox.shrink();

                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: memberAmounts.entries.map((entry) {
                          final phoneNumber = entry.key;
                          final memberAmount = entry.value;

                          final member = members.firstWhere(
                            (m) => m["phoneNumber"] == phoneNumber,
                            orElse: () => {"name": phoneNumber},
                          );

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: chipColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              "${member["name"] ?? "?"} • ₹${memberAmount.toStringAsFixed(0)}",
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      );
                    }

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            12,
                            0,
                            12,
                            12,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 10,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  getExpenseDate(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.people,
                                  size: 10,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "${participantsMap.length}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade50,
                                  Colors.green.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Text(
                              "₹${amount.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          children: [
                            const Divider(height: 16),

                            // Paid By Section
                            if (paidByMap.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Paid By:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              buildCompactMemberChips(
                                paidByMap,
                                Colors.green.shade50,
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Participants Section
                            if (participantsMap.isNotEmpty) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.people,
                                      size: 14,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    "Split:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              buildCompactMemberChips(
                                participantsMap,
                                Colors.orange.shade50,
                              ),
                              const SizedBox(height: 12),
                            ],

                            const Divider(height: 8),
                            const SizedBox(height: 6),

                            // Compact Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    _showEditExpenseDialog(
                                      context,
                                      widget.group["id"],
                                      expenseId,
                                      expense,
                                    );
                                  },
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text(
                                    "Edit",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
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
                                          "Delete '$title'?\n\nThis will reverse all balance changes.",
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
                                        expenseService
                                            .deleteExpenseWithActivity(
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
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text(
                                    "Delete",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
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
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _compactSummaryItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMembersDialog(BuildContext context, Map<String, dynamic> group) {
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
            await expenseService.addExpenseWithActivity(
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
    String groupId,
    String expenseId,
    Map<String, dynamic> expense,
  ) {
    showEditExpenseDialog(
      context,
      groupId: groupId,
      expenseId: expenseId,
      expense: expense,
      onEditExpense:
          ({
            required groupId,
            required expenseId,
            required title,
            required amount,
            required paidBy,
            required participants,
            required oldPaidBy,
            required oldParticipants,
          }) async {
            await expenseService.editExpenseWithActivity(
              groupId: groupId,
              expenseId: expenseId,
              title: title,
              amount: amount,
              paidBy: paidBy,
              participants: participants,
              oldPaidBy: oldPaidBy,
              oldParticipants: oldParticipants,
            );
          },
      streamGroupById: (id) => groupService.streamGroupById(id),
    );
  }
}
