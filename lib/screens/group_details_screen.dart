import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';
import '../constants.dart'; // <- your file where getPurposeIcon is stored

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final FirestoreServices firestoreServices = FirestoreServices();

  final AuthServices authServices = AuthServices();

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
                getPurposeIcon(widget.group["purpose"]), // ✅ purpose icon
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.group["name"] ?? "Group",
              style: TextStyle(color: primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, color: primary),
                label: const Text(
                  "Add Member",
                  style: TextStyle(color: primary),
                ),
                onPressed: () => _showAddMemberDialog(
                  context,
                  authServices.currentUser!.phoneNumber as String,
                  widget.group["name"],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.attach_money, color: primary),
                label: const Text(
                  "Add Expense",
                  style: TextStyle(color: primary),
                ),
                onPressed: () => _showAddExpenseDialog(context),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.group, color: primary),
                label: const Text("Members", style: TextStyle(color: primary)),
                onPressed: () => _showMembersDialog(context, widget.group),
              ),
              // 👇 You can keep adding more buttons here, no overflow issue
            ],
          ),
        ),
      ),
    );
  }

  //Show Members Dialog
  void _showMembersDialog(BuildContext context, Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Group Members"),
        content: StreamBuilder<DocumentSnapshot>(
          stream: firestoreServices
              .getUserDoc(authServices.currentUser as User)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final groups = List<Map<String, dynamic>>.from(
              data["groups"] ?? [],
            );
            final currentGroup = groups.firstWhere(
              (g) => g["name"] == group["name"],
              orElse: () => {},
            );

            final members = List<String>.from(currentGroup["members"] ?? []);

            if (members.isEmpty) {
              return const Text("No members added yet.");
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final phone = members[index];
                  return FutureBuilder<String>(
                    future: firestoreServices.getUserNameByPhone(phone),
                    builder: (context, snapshot) {
                      final displayName = snapshot.data ?? phone;
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(displayName),
                        subtitle: Text(phone),
                      );
                    },
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
  void _showAddMemberDialog(
    BuildContext context,
    String userId,
    String groupName,
  ) {
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
              final newMember = '+91' + controller.text.trim();
              if (newMember.isNotEmpty) {
                await firestoreServices.addMemberToGroup(
                  userId: userId,
                  groupName: groupName,
                  newMemberPhoneNumber: newMember,
                );
                debugPrint("New Member: $newMember");
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(
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
