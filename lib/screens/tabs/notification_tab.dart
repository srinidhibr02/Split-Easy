import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/constants.dart';
import 'package:timeago/timeago.dart' as timeago;

class ModernNotificationScreen extends StatefulWidget {
  const ModernNotificationScreen({super.key});

  @override
  State<ModernNotificationScreen> createState() =>
      _ModernNotificationScreenState();
}

class _ModernNotificationScreenState extends State<ModernNotificationScreen>
    with SingleTickerProviderStateMixin {
  final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? "";
  List<DocumentSnapshot> userGroups = [];
  bool isLoading = true;
  String selectedFilter = "all";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserGroups() async {
    setState(() => isLoading = true);
    final snap = await FirebaseFirestore.instance
        .collection('groups')
        .where('memberPhones', arrayContains: currentUserPhone)
        .get();
    setState(() {
      userGroups = snap.docs;
      isLoading = false;
    });
  }

  Future<List<DocumentSnapshot>> _fetchAllActivities() async {
    List<DocumentSnapshot> allActivities = [];
    for (var group in userGroups) {
      final snapshot = await FirebaseFirestore.instance
          .collection('groups')
          .doc(group.id)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();
      allActivities.addAll(snapshot.docs);
    }
    allActivities.sort((a, b) {
      final aTime = (a['timestamp'] as Timestamp?)?.toDate();
      final bTime = (b['timestamp'] as Timestamp?)?.toDate();
      if (aTime == null || bTime == null) return 0;
      return bTime.compareTo(aTime);
    });
    return allActivities;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }

    if (userGroups.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Column(
            children: [
              _buildModernAppBar(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_none,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "No notifications yet",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Join a group to see activities",
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildModernAppBar(),
            SizedBox(height: 15),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActivityList("all"),
                  _buildActivityList("expenses"),
                  _buildActivityList("group"),
                  _buildActivityList("settlements"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Activity Feed",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "Stay updated with your groups",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: primary),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTabChip(
            icon: Icons.all_inbox,
            label: "All",
            index: 0,
            isSelected: _tabController.index == 0,
          ),
          const SizedBox(width: 8),
          _buildTabChip(
            icon: Icons.receipt_long,
            label: "Expenses",
            index: 1,
            isSelected: _tabController.index == 1,
          ),
          const SizedBox(width: 8),
          _buildTabChip(
            icon: Icons.group,
            label: "Groups",
            index: 2,
            isSelected: _tabController.index == 2,
          ),
          const SizedBox(width: 8),
          _buildTabChip(
            icon: Icons.check_circle,
            label: "Settled",
            index: 3,
            isSelected: _tabController.index == 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [primary, primary.withOpacity(0.8)])
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(String filter) {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _fetchAllActivities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primary));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                ),
                const SizedBox(height: 16),
                Text(
                  "No activities yet",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Activities will appear here",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        List<DocumentSnapshot> activities = snapshot.data!;
        activities = activities.where((activity) {
          final type = activity['type'] ?? '';
          switch (filter) {
            case "expenses":
              return type.contains("expense");
            case "group":
              return type.contains("group") || type.contains("member");
            case "settlements":
              return type.contains("settlement");
            default:
              return true;
          }
        }).toList();

        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No activities in this category",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        Map<String, List<DocumentSnapshot>> groupedActivities = {};
        for (var activity in activities) {
          final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();
          if (timestamp == null) continue;
          final dateKey = _getDateKey(timestamp);
          groupedActivities.putIfAbsent(dateKey, () => []);
          groupedActivities[dateKey]!.add(activity);
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: groupedActivities.length,
            itemBuilder: (context, index) {
              final dateKey = groupedActivities.keys.elementAt(index);
              final dateActivities = groupedActivities[dateKey]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateKey,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dateActivities.map(
                    (activity) => _buildModernActivityCard(activity),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildModernActivityCard(DocumentSnapshot activity) {
    final data = activity.data() as Map<String, dynamic>;
    final type = data['type'] ?? '';
    final title = data['title'] ?? '';
    final description = data['description'] ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final readBy = List<String>.from(data['readBy'] ?? []);
    final isRead = readBy.contains(currentUserPhone);

    final icon = _getActivityIcon(type);
    final color = _getActivityColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : primary.withOpacity(0.3),
          width: isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (!isRead) {
              await activity.reference.update({
                "readBy": FieldValue.arrayUnion([currentUserPhone]),
              });
              setState(() {});
            }
            _handleActivityTap(context, type, metadata);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(
                                  timestamp != null
                                      ? timeago.format(timestamp)
                                      : 'Just now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    if (type.contains('groupCreated')) return Icons.group_add;
    if (type.contains('memberAdded')) return Icons.person_add;
    if (type.contains('memberRemoved')) return Icons.person_remove;
    if (type.contains('expenseAdded')) return Icons.add_circle_outline;
    if (type.contains('expenseEdited')) return Icons.edit_note;
    if (type.contains('expenseDeleted')) return Icons.delete_outline;
    if (type.contains('settlement')) return Icons.check_circle_outline;
    if (type.contains('groupUpdated')) return Icons.update;
    return Icons.notifications;
  }

  Color _getActivityColor(String type) {
    if (type.contains('groupCreated')) return Colors.blue;
    if (type.contains('memberAdded')) return Colors.green;
    if (type.contains('memberRemoved')) return Colors.orange;
    if (type.contains('expenseAdded')) return Colors.purple;
    if (type.contains('expenseEdited')) return Colors.amber;
    if (type.contains('expenseDeleted')) return Colors.red;
    if (type.contains('settlement')) return Colors.teal;
    if (type.contains('groupUpdated')) return Colors.indigo;
    return Colors.grey;
  }

  String _getDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final activityDate = DateTime(date.year, date.month, date.day);

    if (activityDate == today) return 'Today';
    if (activityDate == yesterday) return 'Yesterday';
    if (now.difference(activityDate).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleActivityTap(
    BuildContext context,
    String type,
    Map<String, dynamic> metadata,
  ) {
    // Handle navigation based on activity type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(_getActivityIcon(type), color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Activity: $type'),
          ],
        ),
        backgroundColor: _getActivityColor(type),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
