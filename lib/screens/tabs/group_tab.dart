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
  String _selectedFilter = "All"; // All, Active, Settled

  IconData getPurposeIcon(String? label) {
    final purpose = purposes.firstWhere(
      (p) => p["label"] == label,
      orElse: () => {"icon": Icons.group},
    );
    return purpose["icon"] as IconData;
  }

  Color getPurposeColor(String? label) {
    // You can customize colors based on purpose
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
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
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
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _filterChip("All", Icons.grid_view),
                const SizedBox(width: 8),
                _filterChip("Active", Icons.trending_up),
                const SizedBox(width: 8),
                _filterChip("Settled", Icons.check_circle),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreServices.streamUserGroups(
                  _authServices.currentUser as User,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_add,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No Groups Found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Create your first group to start\nsplitting expenses!",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Filter groups
                  var groups = snapshot.data!.where((group) {
                    // Search filter
                    final groupName = (group["groupName"] ?? "").toLowerCase();
                    final purpose = (group["purpose"] ?? "").toLowerCase();
                    final matchesSearch =
                        _searchQuery.isEmpty ||
                        groupName.contains(_searchQuery.toLowerCase()) ||
                        purpose.contains(_searchQuery.toLowerCase());

                    if (!matchesSearch) return false;

                    // Status filter (you may need to add balance calculation logic)
                    if (_selectedFilter == "Active") {
                      // Assuming groups with expenses are active
                      return (group["expenses"] as List?)?.isNotEmpty ?? false;
                    } else if (_selectedFilter == "Settled") {
                      return (group["expenses"] as List?)?.isEmpty ?? true;
                    }

                    return true;
                  }).toList();

                  if (groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "No groups match your search"
                                : "No $_selectedFilter groups",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final groupName = group["groupName"] ?? "Unnamed";
                      final purpose = group["purpose"] ?? "Other";
                      final memberCount =
                          (group["members"] as List?)?.length ?? 0;
                      final createdAt = group["createdAt"];

                      // Calculate days since creation
                      String getTimeSinceCreation() {
                        if (createdAt == null) return "";
                        try {
                          final DateTime created = (createdAt as dynamic)
                              .toDate();
                          final difference = DateTime.now().difference(created);
                          if (difference.inDays == 0) {
                            return "Created today";
                          } else if (difference.inDays == 1) {
                            return "Created yesterday";
                          } else if (difference.inDays < 30) {
                            return "Created ${difference.inDays} days ago";
                          } else if (difference.inDays < 365) {
                            return "Created ${(difference.inDays / 30).floor()} months ago";
                          } else {
                            return "Created ${(difference.inDays / 365).floor()} years ago";
                          }
                        } catch (e) {
                          return "";
                        }
                      }

                      final purposeColor = getPurposeColor(purpose);

                      return StreamBuilder(
                        stream: _groupService.streamExpenseCount(group["id"]),
                        builder: (context, expenseSnapshot) {
                          final expenseCount = expenseSnapshot.hasData
                              ? expenseSnapshot.data
                              : 0;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        GroupDetailsScreen(group: group),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Group Icon with gradient
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            purposeColor,
                                            purposeColor.withOpacity(0.7),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: purposeColor.withOpacity(
                                              0.3,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        getPurposeIcon(purpose),
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Group Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  groupName,
                                                  style: const TextStyle(
                                                    color: primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (expenseCount == 0)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.green.shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        size: 12,
                                                        color: Colors
                                                            .green
                                                            .shade700,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        "Settled",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors
                                                              .green
                                                              .shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: purposeColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              purpose,
                                              style: TextStyle(
                                                color: purposeColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Stats Row
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.people_outline,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "$memberCount",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.receipt_long,
                                                size: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "$expenseCount",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              if (getTimeSinceCreation()
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 16),
                                                Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    getTimeSinceCreation(),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Arrow
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreateGroupScreen()),
          );
          if (result == true) {
            setState(() {});
          }
        },
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "New Group",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
