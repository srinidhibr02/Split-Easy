import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';
import '../constants.dart'; // <- your file where getPurposeIcon is stored
import 'package:multi_select_flutter/multi_select_flutter.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirestoreServices firestoreServices = FirestoreServices();

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
                    onPressed: () {},
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
                    final expenseDoc = expenses[index]; // QueryDocumentSnapshot
                    final expense = expenseDoc.data() as Map<String, dynamic>;
                    final expenseId =
                        expenseDoc.id; // ✅ This is the document ID

                    final title = expense["title"] ?? "";
                    final amount = expense["amount"]?.toDouble() ?? 0;
                    final splitType = expense["splitType"] ?? "";

                    // Map phone numbers to member info
                    List<Map<String, dynamic>> getMembersInfo(
                      List<dynamic>? phoneList,
                    ) {
                      if (phoneList == null) return [];
                      return phoneList.map((phone) {
                        return members.firstWhere(
                          (m) => m["phoneNumber"] == phone,
                          orElse: () => {
                            "name": phone,
                            "avatar": "",
                          }, // fallback
                        );
                      }).toList();
                    }

                    final paidByInfo = getMembersInfo(
                      expense["paidBy"] as List<dynamic>?,
                    );
                    final participantsInfo = getMembersInfo(
                      expense["participants"] as List<dynamic>?,
                    );

                    Widget buildMemberChips(
                      List<Map<String, dynamic>> infoList,
                    ) {
                      return Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: infoList.map((m) {
                          return Chip(
                            avatar: CircleAvatar(
                              radius: 12,
                              backgroundImage:
                                  m["avatar"] != null && m["avatar"] != ""
                                  ? NetworkImage(m["avatar"])
                                  : const AssetImage(
                                          "assets/default_avatar.png",
                                        )
                                        as ImageProvider,
                            ),
                            label: Text(
                              m["name"] ?? "Unknown",
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
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
                            const Icon(Icons.attach_money, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "₹${amount.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        childrenPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          if (paidByInfo.isNotEmpty) ...[
                            const Text(
                              "Paid By:",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            buildMemberChips(paidByInfo),
                            const SizedBox(height: 8),
                          ],
                          if (participantsInfo.isNotEmpty) ...[
                            const Text(
                              "Participants:",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            buildMemberChips(participantsInfo),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            "Split Type: $splitType",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),

                          // ✅ Action buttons
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
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  // Delete expense
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Delete Expense?"),
                                      content: const Text(
                                        "Are you sure you want to delete this expense?",
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
                                          child: const Text("Delete"),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirebaseFirestore.instance
                                        .collection("groups")
                                        .doc(groupId)
                                        .collection("expenses")
                                        .doc(expenseId)
                                        .delete();
                                    // TODO: Optionally adjust balances if necessary
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  "Delete",
                                  style: TextStyle(color: Colors.red),
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
        content: StreamBuilder<Map<String, dynamic>?>(
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
    List<String> selectedPayers = [];
    List<String> selectedParticipants = [];
    String? selectedSplitType = "Equally";

    final members = (group["members"] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add Expense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: "Expense Title"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(hintText: "Amount"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                MultiSelectDialogField<String>(
                  items: members
                      .map(
                        (e) => MultiSelectItem<String>(
                          e["phoneNumber"] as String,
                          e["name"] as String,
                        ),
                      )
                      .toList(),
                  title: const Text("Select Payers"),
                  buttonText: const Text("Select Payers"),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  buttonIcon: const Icon(Icons.arrow_drop_down),
                  onConfirm: (values) {
                    setState(() {
                      selectedPayers = values.cast<String>();
                    });
                  },
                ),
                const SizedBox(height: 15),
                MultiSelectDialogField<String>(
                  items: members
                      .map(
                        (e) => MultiSelectItem<String>(
                          e["phoneNumber"] as String,
                          e["name"] as String,
                        ),
                      )
                      .toList(),
                  title: const Text("Select Participants"),
                  buttonText: const Text("Select Participants"),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  buttonIcon: const Icon(Icons.arrow_drop_down),
                  onConfirm: (values) {
                    setState(() {
                      selectedParticipants = values.cast<String>();
                    });
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  initialValue: selectedSplitType,
                  decoration: InputDecoration(
                    labelText: "Split Type",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  items: ["Equally", "Unequally"].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSplitType = value;
                    });
                  },
                ),
              ],
            ),
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
                    selectedParticipants.isEmpty ||
                    selectedSplitType == null) {
                  return;
                }

                Navigator.pop(context); // Close first dialog

                if (selectedSplitType == "Equally") {
                  // Calculate splits and contributions
                  final perParticipant =
                      expenseAmount / selectedParticipants.length;
                  final perPayer = expenseAmount / selectedPayers.length;

                  final splits = {
                    for (var p in selectedParticipants) p: perParticipant,
                  };
                  final contributions = {
                    for (var p in selectedPayers) p: perPayer,
                  };

                  debugPrint(
                    "Expense: $expenseTitle | Equally\nSplits: $splits\nContributions: $contributions",
                  );

                  // Call Firestore service
                  firestoreServices.addExpense(
                    groupId: group["id"],
                    title: expenseTitle,
                    amount: expenseAmount,
                    paidBy: selectedPayers,
                    participants: selectedParticipants,
                    splits: splits,
                    contributions: contributions,
                    splitType: selectedSplitType as String,
                  );
                } else {
                  // Unequally → open second dialog
                  _showUnequalSplitDialog(
                    context,
                    group,
                    expenseTitle,
                    expenseAmount,
                    selectedPayers,
                    selectedParticipants,
                    selectedSplitType!,
                  );
                }
              },
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }

  /// Second dialog for Unequal splits
  void _showUnequalSplitDialog(
    BuildContext context,
    Map<String, dynamic> group,
    String title,
    double amount,
    List<String> paidBy,
    List<String> participants,
    String selectedSplitType,
  ) {
    final members = (group["members"] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    final Map<String, TextEditingController> controllers = {
      for (var p in participants) p: TextEditingController(),
    };

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Enter Unequal Splits"),
          content: SingleChildScrollView(
            child: Column(
              children: participants.map((participant) {
                final name = members.firstWhere(
                  (e) => e["phoneNumber"] == participant,
                )["name"];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: TextField(
                    controller: controllers[participant],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "$name's share",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final splits = <String, double>{};
                double totalEntered = 0;

                for (var participant in participants) {
                  final value =
                      double.tryParse(controllers[participant]?.text ?? "0") ??
                      0;
                  splits[participant] = value;
                  totalEntered += value;
                }

                if ((totalEntered - amount).abs() > 0.01) {
                  // Optional: warn if sum mismatch
                  debugPrint(
                    "Warning: Sum of splits ($totalEntered) does not match total amount ($amount)",
                  );
                }

                final perPayer = amount / paidBy.length;
                final contributions = {for (var p in paidBy) p: perPayer};

                debugPrint(
                  "Expense: $title | Unequally\nSplits: $splits\nContributions: $contributions",
                );

                Navigator.pop(context);

                // Call Firestore service
                firestoreServices.addExpense(
                  groupId: group["id"],
                  title: title,
                  amount: amount,
                  paidBy: paidBy,
                  participants: participants,
                  splits: splits,
                  contributions: contributions,
                  splitType: selectedSplitType,
                );
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
      text: (expense["amount"]?.toString() ?? "0"),
    );

    List<String> selectedPayers = List<String>.from(expense["paidBy"] ?? []);
    List<String> selectedParticipants = List<String>.from(
      expense["participants"] ?? [],
    );
    String? selectedSplitType = expense["splitType"];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Expense"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(hintText: "Expense Title"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(hintText: "Amount"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                MultiSelectDialogField(
                  items: group["members"]
                      .map<MultiSelectItem<String>>(
                        (e) => MultiSelectItem<String>(
                          e["phoneNumber"],
                          e["name"],
                        ),
                      )
                      .toList(),
                  title: const Text("Select Payers"),
                  initialValue: selectedPayers,
                  buttonText: const Text("Select Payers"),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  buttonIcon: const Icon(Icons.arrow_drop_down),
                  onConfirm: (values) {
                    setState(() {
                      selectedPayers = values.cast<String>();
                    });
                  },
                ),
                const SizedBox(height: 15),
                MultiSelectDialogField(
                  items: group["members"]
                      .map<MultiSelectItem<String>>(
                        (e) => MultiSelectItem<String>(
                          e["phoneNumber"],
                          e["name"],
                        ),
                      )
                      .toList(),
                  title: const Text("Select Participants"),
                  initialValue: selectedParticipants,
                  buttonText: const Text("Select Participants"),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  buttonIcon: const Icon(Icons.arrow_drop_down),
                  onConfirm: (values) {
                    setState(() {
                      selectedParticipants = values.cast<String>();
                    });
                  },
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedSplitType,
                  decoration: InputDecoration(
                    labelText: "Split Type",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  items: ["Equally", "Unequally"].map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSplitType = value;
                    });
                  },
                ),
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
                    selectedParticipants.isEmpty ||
                    selectedSplitType == null) {
                  return;
                }

                // Calculate splits and contributions (you can extend Unequal later)
                Map<String, double> splits = {};
                Map<String, double> contributions = {};

                if (selectedSplitType == "Equally") {
                  final splitAmount =
                      expenseAmount / selectedParticipants.length;
                  for (var p in selectedParticipants) splits[p] = splitAmount;

                  final contributionAmount =
                      expenseAmount / selectedPayers.length;
                  for (var p in selectedPayers)
                    contributions[p] = contributionAmount;
                }

                // Call Firestore service
                await firestoreServices.updateExpense(
                  groupId: group["id"],
                  expenseId: expenseId,
                  title: expenseTitle,
                  amount: expenseAmount,
                  paidBy: selectedPayers,
                  participants: selectedParticipants,
                  splits: splits,
                  contributions: contributions,
                  splitType: selectedSplitType as String,
                );

                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }
}
