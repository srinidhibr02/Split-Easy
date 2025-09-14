import 'package:flutter/material.dart';
import '../constants.dart'; // <- your file where getPurposeIcon is stored

class GroupDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primary,
              child: Icon(
                color: white,
                getPurposeIcon(group["purpose"]), // ✅ purpose icon
              ),
            ),
            const SizedBox(width: 10),
            Text(
              group["name"] ?? "Group",
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Buttons Side by Side
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add, color: primary),
                    label: const Text(
                      "Add Member",
                      style: TextStyle(color: primary),
                    ),
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.attach_money, color: primary),
                    label: const Text(
                      "Add Expense",
                      style: TextStyle(color: primary),
                    ),
                    onPressed: () => _showAddExpenseDialog(context),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),

            // ✅ Group Info
            Text(
              "Purpose: ${group["purpose"] ?? "N/A"}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "Members: ${group["members"]?.join(", ") ?? "None"}",
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Add Member Dialog
  void _showAddMemberDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Member"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter member name/ID"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newMember = controller.text.trim();
              if (newMember.isNotEmpty) {
                // ✅ TODO: Call FirestoreService().addMemberToGroup()
                debugPrint("New Member: $newMember");
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // ✅ Add Expense Dialog
  void _showAddExpenseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Expense"),
        content: Column(
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
          ],
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

              if (expenseTitle.isNotEmpty && expenseAmount > 0) {
                // ✅ TODO: Call FirestoreService().addExpenseToGroup()
                debugPrint("Expense: $expenseTitle - ₹$expenseAmount");
              }
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
