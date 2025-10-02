import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/screens/settlement.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';
import 'package:split_easy/services/group_services.dart';
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

  @override
  Widget build(BuildContext context) {
    final groupId = widget.group["id"];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primary,
              child: Icon(
                color: white,
                getPurposeIcon(widget.group["purpose"]),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.group["groupName"] ?? "Group",
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _roundButton(
                    icon: Icons.person_add,
                    label: "Add Member",
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                  const SizedBox(width: 20),
                  _roundButton(
                    icon: Icons.attach_money,
                    label: "Add Expense",
                    onPressed: () =>
                        _showAddExpenseDialog(context, widget.group),
                  ),
                  const SizedBox(width: 20),
                  _roundButton(
                    icon: Icons.group,
                    label: "Members",
                    onPressed: () => _showMembersDialog(context, widget.group),
                  ),
                  const SizedBox(width: 20),
                  _roundButton(
                    icon: Icons.summarize,
                    label: "Totals",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: const Text("Settlement")),
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

          const SizedBox(height: 20),

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
                  return const Center(
                    child: Text(
                      "No expenses yet",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
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

                    // Get paidBy and participants as Map<String, double>
                    final paidByMap = Map<String, double>.from(
                      expense["paidBy"] ?? {},
                    );
                    final participantsMap = Map<String, double>.from(
                      expense["participants"] ?? {},
                    );

                    // Build member info with amounts
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

                          // Find member info
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
                                          "assets/default_avatar.png",
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                "₹${amount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.all(16),
                        children: [
                          // Paid By Section
                          if (paidByMap.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Paid By:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            buildMemberChips(paidByMap, Colors.green.shade50),
                            const SizedBox(height: 16),
                          ],

                          // Participants Section
                          if (participantsMap.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  size: 18,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Split Between:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
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
                              TextButton.icon(
                                onPressed: () {
                                  // Open edit dialog
                                  _showEditExpenseDialog(
                                    context,
                                    expenseId,
                                    expense,
                                    widget.group,
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text("Edit"),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  // Delete expense with confirmation
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Delete Expense?"),
                                      content: Text(
                                        "Are you sure you want to delete '$title'?\n\nNote: This will reverse the balance changes.",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      // Call delete function that reverses balances
                                      await firestoreServices.deleteExpense(
                                        groupId: groupId,
                                        expenseId: expenseId,
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
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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
          stream: firestoreServices.streamGroupById(group["id"]),
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
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Member", style: TextStyle(color: primary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: "Enter 10-digit phone number",
            counterText: "",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: primary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newMember = '+91${controller.text.trim()}';
              if (newMember.isNotEmpty) {
                await firestoreServices.addMemberToGroup(
                  groupId: widget.group["id"],
                  newMemberPhoneNumber: newMember,
                );
                debugPrint("New Member: $newMember");
              }
              // ignore: use_build_context_synchronously
              Navigator.pop(context);
              ScaffoldMessenger.of(
                // ignore: use_build_context_synchronously
                context,
              ).showSnackBar(const SnackBar(content: Text("Member added")));
            },
            child: const Text("Add", style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
  }

  // ✅ Add Expense Dialog
  void _showAddExpenseDialog(BuildContext context, Map<String, dynamic> group) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    Map<String, double> selectedPayers = {};
    Map<String, double> selectedParticipants = {};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add Expense"),
          content: StreamBuilder<DocumentSnapshot>(
            stream: firestoreServices.streamGroupById(group["id"]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final updatedGroup =
                  snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final members = (updatedGroup["members"] as List<dynamic>? ?? [])
                  .map((e) => e as Map<String, dynamic>)
                  .toList();

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Expense Title",
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(hintText: "Amount"),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),

                    // --- Payers Section ---
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

                    // --- Show selected payers ---
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
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

                    // --- Participants Section ---
                    InkWell(
                      onTap: () async {
                        double expAmount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final result = await showDialog(
                          context: context,
                          builder: (_) => MemberSelectionDialog(
                            members: members,
                            amount: expAmount,
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

                    // --- Show selected participants ---
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
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
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final expenseTitle = titleController.text.trim();
                final expenseAmount =
                    double.tryParse(amountController.text.trim()) ?? 0;

                if (expenseTitle.isEmpty ||
                    expenseAmount <= 0 ||
                    selectedPayers.isEmpty ||
                    selectedParticipants.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                // Firestore service call
                groupService.addExpenseWithActivity(
                  groupId: group["id"],
                  title: expenseTitle,
                  amount: expenseAmount,
                  paidBy: selectedPayers,
                  participants: selectedParticipants,
                );

                Navigator.pop(context);
              },
              child: const Text("Add Expense"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(40),
          child: CircleAvatar(
            radius: 28, // size of circle
            // ignore: deprecated_member_use
            backgroundColor: primary.withOpacity(0.1),
            child: Icon(icon, color: primary, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
                    print('=== Edit Expense Debug ===');
                    print('Expense Title: $expenseTitle');
                    print('Expense Amount: $expenseAmount');
                    print('Old PaidBy: $oldPaidBy');
                    print('Old Participants: $oldParticipants');
                    print('New PaidBy: $selectedPayers');
                    print('New Participants: $selectedParticipants');

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
                    print('Error in dialog: $e');
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
