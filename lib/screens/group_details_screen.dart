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
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                getPurposeIcon(widget.group["purpose"]),
                color: Colors.white,
                size: 22,
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
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.group["purpose"] ?? "",
                    style: TextStyle(
                      color: primary.withOpacity(0.7),
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
          // ✨ Summary Card
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

              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 18,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.white.withOpacity(0.9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      Icons.people,
                      "$memberCount",
                      "Members",
                      Colors.indigoAccent,
                    ),
                    _divider(),
                    _summaryItem(
                      Icons.receipt_long,
                      "$expenseCount",
                      "Expenses",
                      Colors.teal,
                    ),
                    _divider(),
                    _summaryItem(
                      Icons.currency_rupee,
                      totalAmount.toStringAsFixed(0),
                      "Total",
                      Colors.orange,
                    ),
                  ],
                ),
              );
            },
          ),

          // ✨ Modern Action Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _modernButton(
                    icon: Icons.person_add_alt_1,
                    label: "Add Member",
                    color: Colors.blueAccent,
                    onPressed: () => _showAddMemberDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modernButton(
                    icon: Icons.add_circle_outline,
                    label: "Expense",
                    color: Colors.greenAccent.shade700,
                    onPressed: () =>
                        _showAddExpenseDialog(context, widget.group),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modernButton(
                    icon: Icons.groups_2,
                    label: "Members",
                    color: Colors.purpleAccent,
                    onPressed: () => _showMembersDialog(context, widget.group),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modernButton(
                    icon: Icons.payments_outlined,
                    label: "Settlement",
                    color: Colors.orangeAccent.shade700,
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
                            body: ModernSettlementScreen(
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

          const SizedBox(height: 10),

          // ✨ Recent Expenses Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, color: primary, size: 20),
                const SizedBox(width: 6),
                const Text(
                  "Recent Expenses",
                  style: TextStyle(
                    fontSize: 17,
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
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // ✨ Expense List
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
                      "No expenses yet. Add your first one!",
                      style: TextStyle(color: Colors.grey),
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
                    final title = expense["title"] ?? "";
                    final amount = expense["amount"]?.toDouble() ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, primary.withOpacity(0.7)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.receipt_long,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        subtitle: const Text(
                          "Tap to view details",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "₹${amount.toStringAsFixed(0)}",
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onTap: () => _showEditExpenseDialog(
                          context,
                          widget.group["id"],
                          expenseDoc.id,
                          expense,
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

      // ✨ Floating Action Button
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 22.0, right: 20.0),
        child: FloatingActionButton(
          onPressed: () {
            _showAddExpenseDialog(context, widget.group);
          },
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 35, width: 1, color: Colors.grey.shade300);

  Widget _summaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ✨ Modern Button Widget
  Widget _modernButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.95),
        elevation: 6,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        shadowColor: color.withOpacity(0.4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showMembersDialog(BuildContext context, Map<String, dynamic> group) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Group Members",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            group["groupName"] ?? "Unknown Group",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Members List
              Flexible(
                child: StreamBuilder(
                  stream: streams.streamGroupById(group["id"]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final groupData = snapshot.data!;
                    final members = List<Map<String, dynamic>>.from(
                      groupData["members"] ?? [],
                    );

                    if (members.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No members added yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final displayName =
                            member["name"] ?? member["phoneNumber"];
                        final phone = member["phoneNumber"] ?? "Unknown";
                        final isCurrentUser =
                            phone == authServices.currentUser?.phoneNumber;

                        // Inside ListView.builder’s itemBuilder:
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading:
                                (member["avatar"] != null &&
                                    member["avatar"] != "default_avatar" &&
                                    member["avatar"].toString().isNotEmpty)
                                ? CircleAvatar(
                                    backgroundImage: NetworkImage(
                                      member["avatar"],
                                    ),
                                    radius: 24,
                                  )
                                : CircleAvatar(
                                    backgroundImage: const AssetImage(
                                      'images/default_avatar.png',
                                    ),
                                    backgroundColor: Colors.grey[200],
                                    radius: 24,
                                  ),

                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              phone,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            trailing: !isCurrentUser
                                ? IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red.shade600,
                                    ),
                                    onPressed: () => _confirmRemoveMember(
                                      context,
                                      group["id"],
                                      member,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddMemberDialog(context),
                        icon: Icon(Icons.person_add, color: primary),
                        label: Text(
                          "Add Member",
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Done",
                          style: TextStyle(
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

  // Add this confirmation method for removing members
  void _confirmRemoveMember(
    BuildContext context,
    String groupId,
    Map<String, dynamic> member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_remove,
                  color: Colors.red.shade600,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Remove Member?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Are you sure you want to remove ${member["name"]} from this group?",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Remove",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    // Check for pending suggestedSettlements
    final groupDoc = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId);
    final fromQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('fromPhone', isEqualTo: member['phoneNumber'])
        .limit(1)
        .get();
    final toQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('toPhone', isEqualTo: member['phoneNumber'])
        .limit(1)
        .get();
    final hasSettlements = fromQuery.docs.isNotEmpty || toQuery.docs.isNotEmpty;

    if (hasSettlements) {
      final warn = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 60,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Pending Settlements",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "${member["name"]} has pending settlements in this group. Removing them will delete those records. Continue?",
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Remove",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (warn != true) return;
    }

    try {
      await groupService.removeMemberFromGroup(
        groupId: groupId,
        memberPhoneNumber: member["phoneNumber"],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${member["name"]} removed successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to remove member: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showAddMemberDialog(BuildContext context) {
    showAddMemberDialog(
      context,
      groupId: widget.group["id"],
      onAddMember: (phoneNumber, {String? customName}) async {
        final whoAdded = authServices.currentUser?.phoneNumber;
        await groupService.addMemberToGroup(
          groupId: widget.group["id"],
          newMemberPhoneNumber: phoneNumber,
          addedByPhoneNumber: whoAdded as String,
          customName: customName, // Pass customName if exists
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
      onDeleteExpense:
          ({
            required String groupId,
            required String expenseId,
            required String expenseTitle,
            required double amount,
            required Map<String, double> paidBy,
            required Map<String, double> participants,
          }) async {
            await expenseService.deleteExpenseWithActivity(
              groupId: groupId,
              expenseId: expenseId,
              expenseTitle: expenseTitle,
              amount: amount,
              paidBy: paidBy,
              participants: participants,
            );
          },
      streamGroupById: (id) => groupService.streamGroupById(id),
    );
  }
}
