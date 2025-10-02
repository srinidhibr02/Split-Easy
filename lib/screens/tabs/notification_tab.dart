import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/constants.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final currentUserPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? "";
  List<DocumentSnapshot> userGroups = [];
  bool isLoading = true;

  // 👇 moved here instead of inside build
  String selectedFilter = "all"; // all, expenses, group, settlements

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
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

    // Sort all activities by timestamp
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (userGroups.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                "No notifications yet",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Join a group to see activities",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        toolbarHeight: 70, // slightly taller
        centerTitle: true,
        title: const Text(
          'Activity Feed',
          style: TextStyle(
            fontSize: 24, // 👈 bigger title
            fontWeight: FontWeight.bold,
            color: primary, // 👈 use your primary color
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: primary, size: 28),
              onPressed: () => _showFilterOptions(context),
              tooltip: 'Filter',
            ),
          ),
        ],
      ),

      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchAllActivities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No activities yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Activities will appear here",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // Apply filter BEFORE grouping
          List<DocumentSnapshot> activities = snapshot.data!;

          activities = activities.where((activity) {
            final type = activity['type'] ?? '';
            switch (selectedFilter) {
              case "expenses":
                return type.startsWith("ActivityType.expense");
              case "group":
                return type == "ActivityType.groupCreated" ||
                    type == "ActivityType.groupUpdated" ||
                    type == "ActivityType.memberAdded" ||
                    type == "ActivityType.memberRemoved";
              case "settlements":
                return type == "ActivityType.settlementRecorded";
              default:
                return true; // all
            }
          }).toList();

          // Group activities by date
          Map<String, List<DocumentSnapshot>> groupedActivities = {};
          for (var activity in activities) {
            final timestamp = (activity['timestamp'] as Timestamp?)?.toDate();
            if (timestamp == null) continue;

            final dateKey = _getDateKey(timestamp);
            groupedActivities.putIfAbsent(dateKey, () => []);
            groupedActivities[dateKey]!.add(activity);
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {}); // Trigger rebuild to refetch
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groupedActivities.length,
              itemBuilder: (context, index) {
                final dateKey = groupedActivities.keys.elementAt(index);
                final dateActivities = groupedActivities[dateKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        dateKey,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    ...dateActivities.map(
                      (activity) => _buildActivityTile(activity),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityTile(DocumentSnapshot activity) {
    final data = activity.data() as Map<String, dynamic>;
    final type = data['type'] ?? '';
    final title = data['title'] ?? '';
    final description = data['description'] ?? '';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    // Per-user read tracking
    final readBy = List<String>.from(data['readBy'] ?? []);
    final isRead = readBy.contains(currentUserPhone);

    final icon = _getActivityIcon(type);
    final color = _getActivityColor(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRead ? Colors.grey.shade200 : primary.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  timestamp != null ? timeago.format(timestamp) : 'Just now',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        trailing: !isRead
            ? Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () async {
          if (!isRead) {
            await activity.reference.update({
              "readBy": FieldValue.arrayUnion([currentUserPhone]),
            });
          }
          _handleActivityTap(context, type, metadata);
        },
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'ActivityType.groupCreated':
        return Icons.group_add;
      case 'ActivityType.memberAdded':
        return Icons.person_add;
      case 'ActivityType.memberRemoved':
        return Icons.person_remove;
      case 'ActivityType.expenseAdded':
        return Icons.add_circle;
      case 'ActivityType.expenseEdited':
        return Icons.edit;
      case 'ActivityType.expenseDeleted':
        return Icons.delete;
      case 'ActivityType.settlementRecorded':
        return Icons.check_circle;
      case 'ActivityType.groupUpdated':
        return Icons.update;
      default:
        return Icons.notifications;
    }
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'ActivityType.groupCreated':
        return Colors.blue;
      case 'ActivityType.memberAdded':
        return Colors.green;
      case 'ActivityType.memberRemoved':
        return Colors.orange;
      case 'ActivityType.expenseAdded':
        return Colors.purple;
      case 'ActivityType.expenseEdited':
        return Colors.amber;
      case 'ActivityType.expenseDeleted':
        return Colors.red;
      case 'ActivityType.settlementRecorded':
        return Colors.teal;
      case 'ActivityType.groupUpdated':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activity tapped: $type'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Activities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inbox),
              title: const Text('All Activities'),
              onTap: () {
                setState(() => selectedFilter = "all");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Expenses Only'),
              onTap: () {
                setState(() => selectedFilter = "expenses");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Group Activities'),
              onTap: () {
                setState(() => selectedFilter = "group");
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('Settlements'),
              onTap: () {
                setState(() => selectedFilter = "settlements");
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
