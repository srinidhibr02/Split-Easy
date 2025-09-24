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
              widget.group["groupName"] ?? "Group",
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
              _roundButton(
                icon: Icons.person_add,
                label: "Add Member",
                onPressed: () => _showAddMemberDialog(context),
              ),
              const SizedBox(width: 20),
              _roundButton(
                icon: Icons.attach_money,
                label: "Add Expense",
                onPressed: () => _showAddExpenseDialog(
                  context,
                  List<String>.from(widget.group["members"] ?? []),
                ),
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
  void _showAddExpenseDialog(BuildContext context, List<String> members) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    // For multiple payers
    List<String> selectedPayers = [];

    // For split type
    String? selectedSplitType;

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

                // ✅ Multi Select Dropdown for Payers
                MultiSelectDialogField(
                  items: members
                      .map((e) => MultiSelectItem<String>(e, e))
                      .toList(),
                  title: const Text("Select Payers"),
                  buttonText: const Text("Select Payers"),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  buttonIcon: const Icon(Icons.arrow_drop_down), // bottom arrow
                  onConfirm: (values) {
                    setState(() {
                      selectedPayers = values.cast<String>();
                    });
                  },
                ),

                const SizedBox(height: 15),

                // ✅ Dropdown for Split Type
                DropdownButtonFormField<String>(
                  initialValue: selectedSplitType,
                  decoration: InputDecoration(
                    labelText: "Split Type",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: const Icon(
                      Icons.arrow_drop_down,
                    ), // bottom arrow
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

                if (expenseTitle.isNotEmpty &&
                    expenseAmount > 0 &&
                    selectedPayers.isNotEmpty &&
                    selectedSplitType != null) {
                  // ✅ Call Firestore Service
                  debugPrint(
                    "Expense: $expenseTitle - ₹$expenseAmount | "
                    "Payers: $selectedPayers | Split: $selectedSplitType",
                  );
                }

                Navigator.pop(context);
              },
              child: const Text("Add"),
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
}
