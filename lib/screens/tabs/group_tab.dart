import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/screens/create_group_screen.dart';
import 'package:split_easy/screens/group_details_screen.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';
import 'package:split_easy/services/group_services.dart';

class GroupTab extends StatefulWidget {
  const GroupTab({super.key});

  @override
  State<GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends State<GroupTab> {
  final FirestoreServices _firestoreServices = FirestoreServices();
  final GroupService _groupService = GroupService();
  final AuthServices _authServices = AuthServices();

  String _searchQuery = "";
  final String _selectedFilter = "All";

  IconData getPurposeIcon(String? label) {
    final purpose = purposes.firstWhere(
      (p) => p["label"] == label,
      orElse: () => {"icon": Icons.group},
    );
    return purpose["icon"] as IconData;
  }

  Color getPurposeColor(String? label) {
    final colorMap = {
      "Trip": Colors.blue,
      "Home": Colors.orange,
      "Couple": Colors.pink,
      "Group": Colors.purple,
      "Event": primary,
      "Project": Colors.green,
      "Other": Colors.grey,
    };
    return colorMap[label] ?? primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "My Groups",
          style: TextStyle(fontWeight: FontWeight.bold, color: primary),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: "Search groups...",
                prefixIcon: const Icon(Icons.search, color: primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => setState(() => _searchQuery = ""),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                  borderSide: BorderSide.none,
                ),
                fillColor: Colors.grey.shade100,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _firestoreServices.streamUserGroups(
            _authServices.currentUser as User,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _emptyState();
            }

            var groups = snapshot.data!.where((group) {
              final groupName = (group["groupName"] ?? "").toLowerCase();
              final purpose = (group["purpose"] ?? "").toLowerCase();
              return _searchQuery.isEmpty ||
                  groupName.contains(_searchQuery.toLowerCase()) ||
                  purpose.contains(_searchQuery.toLowerCase());
            }).toList();
            if (groups.isEmpty) return _emptySearchState();

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) => _modernGroupCard(groups[idx]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGroupScreen()),
          );
          if (result == true) setState(() {});
        },
        backgroundColor: primary,
        icon: const Icon(Icons.group_add, color: Colors.white),
        label: const Text(
          "New Group",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 5,
      ),
    );
  }

  Widget _modernGroupCard(Map<String, dynamic> group) {
    final groupName = group["groupName"] ?? "Unnamed";
    final purpose = group["purpose"] ?? "Other";
    final memberCount = (group["members"] as List?)?.length ?? 0;
    final createdAt = group["createdAt"];
    final purposeColor = getPurposeColor(purpose);

    String getTimeSinceCreation() {
      if (createdAt == null) return "";
      try {
        final DateTime created = (createdAt as dynamic).toDate();
        final diff = DateTime.now().difference(created);
        if (diff.inDays == 0) return "Today";
        if (diff.inDays == 1) return "Yesterday";
        if (diff.inDays < 30) return "${diff.inDays} days ago";
        if (diff.inDays < 365)
          return "${(diff.inDays / 30).floor()} months ago";
        return "${(diff.inDays / 365).floor()} years ago";
      } catch (e) {
        return "";
      }
    }

    return StreamBuilder<int>(
      stream: _groupService.streamExpenseCount(group["id"]),
      builder: (context, expenseSnapshot) {
        final expenseCount = expenseSnapshot.hasData ? expenseSnapshot.data : 0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeIn,
          margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: purposeColor.withOpacity(0.10),
                blurRadius: 28,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupDetailsScreen(group: group),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 21,
                  horizontal: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            purposeColor.withOpacity(0.96),
                            purposeColor.withOpacity(0.67),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        getPurposeIcon(purpose),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  groupName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: primary,
                                    letterSpacing: 0.07,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (expenseCount == 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 10),
                                  child: _chip(
                                    "Settled",
                                    Icons.check_circle,
                                    Colors.green.shade50,
                                    Colors.green,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _chip(
                                purpose,
                                null,
                                purposeColor.withOpacity(0.15),
                                purposeColor,
                              ),
                              const SizedBox(width: 7),
                              if (getTimeSinceCreation().isNotEmpty)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      getTimeSinceCreation(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          Row(
                            children: [
                              _infoIcon(Icons.people_outline, "$memberCount"),
                              const SizedBox(width: 14),
                              _infoIcon(Icons.receipt_long, "$expenseCount"),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 30,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(
    String label,
    IconData? icon,
    Color bgColor, [
    Color? textColor,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor ?? Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: textColor ?? primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon, String text, {bool isSmall = false}) {
    return Row(
      children: [
        Icon(icon, size: isSmall ? 13 : 16, color: Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: isSmall ? 12 : 13.5,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 78, color: Colors.grey.shade200),
            const SizedBox(height: 20),
            const Text(
              "No Groups Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: primary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Create your first group to begin\nsplitting expenses!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptySearchState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade200),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? "No groups match your search"
                  : "No $_selectedFilter groups",
              style: const TextStyle(
                fontSize: 17,
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Try another search or start\na new group.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
