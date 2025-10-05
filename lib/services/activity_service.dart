import 'package:cloud_firestore/cloud_firestore.dart';

// Activity types
enum ActivityType {
  groupCreated,
  memberAdded,
  memberRemoved,
  expenseAdded,
  expenseEdited,
  expenseDeleted,
  settlementRecorded,
  groupUpdated,
}

// Service to create activities
class ActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create activity when group is created
  Future<void> createGroupActivity({
    required String groupId,
    required String groupName,
    required String creatorPhone,
    required String creatorName,
  }) async {
    await _createActivity(
      groupId: groupId,
      type: ActivityType.groupCreated,
      actorPhone: creatorPhone,
      actorName: creatorName,
      title: "Group created",
      description: "$creatorName created the group \"$groupName\"",
      metadata: {"groupName": groupName},
    );
  }

  // Create activity when member is added
  Future<void> memberAddedActivity({
    required String groupId,
    required String groupName,
    required String addedByPhone,
    required String addedByName,
    required String newMemberPhone,
    required String newMemberName,
  }) async {
    await _createActivity(
      groupId: groupId,
      type: ActivityType.memberAdded,
      actorPhone: addedByPhone,
      actorName: addedByName,
      title: "Member added",
      description: "$addedByName added $newMemberName to \"$groupName\"",
      metadata: {
        "groupName": groupName,
        "newMemberPhone": newMemberPhone,
        "newMemberName": newMemberName,
      },
    );
  }

  // Create activity when member is removed
  Future<void> memberRemovedActivity({
    required String groupId,
    required String groupName,
    required String removedByPhone,
    required String removedByName,
    required String removedMemberPhone,
    required String removedMemberName,
  }) async {
    await _createActivity(
      groupId: groupId,
      type: ActivityType.memberRemoved,
      actorPhone: removedByPhone,
      actorName: removedByName,
      title: "Member removed",
      description:
          "$removedByName removed $removedMemberName from \"$groupName\"",
      metadata: {
        "groupName": groupName,
        "removedMemberPhone": removedMemberPhone,
        "removedMemberName": removedMemberName,
      },
    );
  }

  // Create activity when expense is added
  Future<void> expenseAddedActivity({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required String addedByPhone,
    required String addedByName,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    String payersText = paidBy.length == 1
        ? addedByName
        : "${paidBy.length} people";

    await _createActivity(
      groupId: groupId,
      type: ActivityType.expenseAdded,
      actorPhone: addedByPhone,
      actorName: addedByName,
      title: "Expense added",
      description:
          "$addedByName added \"$expenseTitle\" (₹${amount.toStringAsFixed(2)}) in \"$groupName\"",
      metadata: {
        "groupName": groupName,
        "expenseId": expenseId,
        "expenseTitle": expenseTitle,
        "amount": amount,
        "payersText": payersText,
      },
    );
  }

  // Create activity when expense is edited
  Future<void> expenseEditedActivity({
    required String groupId,
    required String groupName,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required String editedByPhone,
    required String editedByName,
  }) async {
    await _createActivity(
      groupId: groupId,
      type: ActivityType.expenseEdited,
      actorPhone: editedByPhone,
      actorName: editedByName,
      title: "Expense updated",
      description: "$editedByName updated \"$expenseTitle\" in \"$groupName\"",
      metadata: {
        "groupName": groupName,
        "expenseId": expenseId,
        "expenseTitle": expenseTitle,
        "amount": amount,
      },
    );
  }

  // Create activity when expense is deleted
  Future<void> expenseDeletedActivity({
    required String groupId,
    required String groupName,
    required String expenseTitle,
    required double amount,
    required String deletedByPhone,
    required String deletedByName,
  }) async {
    await _createActivity(
      groupId: groupId,
      type: ActivityType.expenseDeleted,
      actorPhone: deletedByPhone,
      actorName: deletedByName,
      title: "Expense deleted",
      description:
          "$deletedByName deleted \"$expenseTitle\" (₹${amount.toStringAsFixed(2)}) from \"$groupName\"",
      metadata: {
        "groupName": groupName,
        "expenseTitle": expenseTitle,
        "amount": amount,
      },
    );
  }

  Future<void> recordSettlement({
    required String groupId,
    required String fromPhone,
    required String toPhone,
    required double amount,
    required String fromName,
    required String toName,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);

      await _firestore.runTransaction((transaction) async {
        final groupSnapshot = await transaction.get(groupRef);

        if (!groupSnapshot.exists) {
          throw Exception('Group not found');
        }

        final groupData = groupSnapshot.data() as Map<String, dynamic>;
        final members = List<Map<String, dynamic>>.from(
          groupData['members'] as List<dynamic>,
        );

        bool fromFound = false;
        bool toFound = false;

        for (var i = 0; i < members.length; i++) {
          final member = members[i];
          final phoneNumber = member['phoneNumber'] as String;

          if (phoneNumber == fromPhone) {
            final currentBalance = (member['balance'] ?? 0.0) as num;
            members[i]['balance'] = currentBalance.toDouble() + amount;
            fromFound = true;
          } else if (phoneNumber == toPhone) {
            final currentBalance = (member['balance'] ?? 0.0) as num;
            members[i]['balance'] = currentBalance.toDouble() - amount;
            toFound = true;
          }

          if (fromFound && toFound) break;
        }

        if (!fromFound || !toFound) {
          throw Exception('One or both members not found');
        }

        transaction.update(groupRef, {'members': members});

        // Record settlement document
        final settlementRef = groupRef.collection('settlements').doc();
        transaction.set(settlementRef, {
          'fromPhone': fromPhone,
          'fromName': fromName,
          'toPhone': toPhone,
          'toName': toName,
          'amount': amount,
          'timestamp': FieldValue.serverTimestamp(),
          'recordedAt': DateTime.now().toIso8601String(),
        });
      });

      // ✅ Record activity after successful transaction
      await _createActivity(
        groupId: groupId,
        type: ActivityType.settlementRecorded,
        actorPhone: fromPhone,
        actorName: fromName,
        title: "Settlement Recorded",
        description: "$fromName paid $toName ₹${amount.toStringAsFixed(2)}",
        metadata: {
          "fromPhone": fromPhone,
          "fromName": fromName,
          "toPhone": toPhone,
          "toName": toName,
          "amount": amount,
        },
      );
    } catch (e) {
      throw Exception('Failed to record settlement: $e');
    }
  }

  // Generic method to create activity
  Future<void> _createActivity({
    required String groupId,
    required ActivityType type,
    required String actorPhone,
    required String actorName,
    required String title,
    required String description,
    required Map<String, dynamic> metadata,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('activities')
        .add({
          'type': type.toString(),
          'actorPhone': actorPhone,
          'actorName': actorName,
          'title': title,
          'description': description,
          'metadata': metadata,
          'timestamp': FieldValue.serverTimestamp(),
          'readBy': [], // Track users who have read this activity
        });
  }

  // Get activities for a specific user (from all their groups)
  Stream<QuerySnapshot> getUserActivities(List<String> groupIds) {
    if (groupIds.isEmpty) {
      return Stream.value(
        FirebaseFirestore.instance.collection('activities').snapshots()
            as QuerySnapshot,
      );
    }

    return _firestore
        .collection('activities')
        .where('groupId', whereIn: groupIds)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  // Get activities for a specific group
  Stream<QuerySnapshot> getGroupActivities(String groupId) {
    return _firestore
        .collection('activities')
        .where('groupId', isEqualTo: groupId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark activity as read
  Future<void> markActivityAsRead(String activityId) async {
    await _firestore.collection('activities').doc(activityId).update({
      'isRead': true,
    });
  }

  // Delete old activities (optional, for cleanup)
  Future<void> deleteOldActivities({int daysOld = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    final oldActivities = await _firestore
        .collection('activities')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    WriteBatch batch = _firestore.batch();
    for (var doc in oldActivities.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
