import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/settlement_service.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserPhone => _auth.currentUser?.phoneNumber ?? "";

  /// Stream groups for the current user based on subcollection
  Stream<List<Map<String, dynamic>>> getUserGroupsStream() {
    final userDoc = _firestore.collection("users").doc(currentUserPhone);

    return userDoc.snapshots().asyncExpand((snapshot) {
      if (!snapshot.exists) return Stream.value([]);

      final groupIds = List<String>.from(snapshot.data()?["groups"] ?? []);

      if (groupIds.isEmpty) return Stream.value([]);

      return _firestore
          .collection("groups")
          .where(FieldPath.documentId, whereIn: groupIds)
          .snapshots()
          .map((query) {
            return query.docs.map((doc) {
              final data = doc.data();
              data["id"] = doc.id;
              return data;
            }).toList();
          });
    });
  }

  Stream<int> streamExpenseCount(String groupId) {
    return _firestore
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Get the balance of the current user in a group
  double getUserBalanceInGroup(Map<String, dynamic> group) {
    final members = group["members"] as List<dynamic>? ?? [];
    for (var member in members) {
      if (member["phoneNumber"] == currentUserPhone) {
        return (member["balance"] ?? 0.0).toDouble();
      }
    }
    return 0.0;
  }

  double getMyBalance(Map<String, dynamic> group) {
    final members = group["members"] as List<dynamic>? ?? [];
    for (var member in members) {
      if (member["phoneNumber"] == currentUserPhone) {
        return (member["balance"] ?? 0.0).toDouble();
      }
    }
    return 0.0;
  }

  /// Calculate overall balance across groups
  double getTotalBalance(List<Map<String, dynamic>> groups) {
    double total = 0;
    for (var group in groups) {
      total += getUserBalanceInGroup(group);
    }
    return total;
  }

  Stream<List<Map<String, dynamic>>> getGroupExpensesStream(String groupId) {
    return _firestore
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {"id": doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> addExpenseWithActivity({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";
    print("$currentUserPhone is adding expense");

    // Get current user name and group name (outside transaction)
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      String? expenseId;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId);
        final groupSnapshot = await transaction.get(groupRef);

        final expenseRef = groupRef.collection('expenses').doc();
        expenseId = expenseRef.id;

        final expenseData = {
          "title": title,
          "amount": amount,
          "paidBy": paidBy,
          "participants": participants,
          "createdAt": FieldValue.serverTimestamp(),
        };

        Map<String, double> balanceChanges = {};
        paidBy.forEach((phoneNumber, amountPaid) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) + amountPaid;
        });
        participants.forEach((phoneNumber, amountOwed) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) - amountOwed;
        });

        List<dynamic> members = groupSnapshot.get('members') ?? [];
        List<Map<String, dynamic>> updatedMembers = members.map((member) {
          Map<String, dynamic> memberMap = Map<String, dynamic>.from(member);
          String phoneNumber = memberMap['phoneNumber'];

          if (balanceChanges.containsKey(phoneNumber)) {
            double currentBalance = (memberMap['balance'] ?? 0.0).toDouble();
            memberMap['balance'] =
                currentBalance + balanceChanges[phoneNumber]!;
          }

          return memberMap;
        }).toList();

        transaction.set(expenseRef, expenseData);
        transaction.update(groupRef, {'members': updatedMembers});
      });

      // Update friend balances
      await _updateAllMemberBalances(groupId);

      // Update suggested settlements
      await SettlementService().updateSuggestedSettlements(groupId);

      await ActivityService().expenseAddedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseId: expenseId ?? 'unknown',
        expenseTitle: title,
        amount: amount,
        addedByPhone: currentUserPhone,
        addedByName: userName,
        paidBy: paidBy,
        participants: participants,
      );

      print(
        'Expense, balances, settlements, and activity created successfully',
      );
    } catch (e) {
      print('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> editExpenseWithActivity({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
    required Map<String, double> oldPaidBy,
    required Map<String, double> oldParticipants,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference groupRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId);

        DocumentSnapshot groupSnapshot = await transaction.get(groupRef);

        if (!groupSnapshot.exists) {
          throw Exception('Group not found');
        }

        List<dynamic> members = groupSnapshot.get('members') ?? [];

        Map<String, double> balanceChanges = {};

        // Reverse old balance changes
        oldPaidBy.forEach((phoneNumber, amountPaid) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) - amountPaid;
        });

        oldParticipants.forEach((phoneNumber, amountOwed) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) + amountOwed;
        });

        // Apply new balance changes
        paidBy.forEach((phoneNumber, amountPaid) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) + amountPaid;
        });

        participants.forEach((phoneNumber, amountOwed) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) - amountOwed;
        });

        List<Map<String, dynamic>> updatedMembers = members.map((member) {
          Map<String, dynamic> memberMap = Map<String, dynamic>.from(member);
          String phoneNumber = memberMap['phoneNumber'];

          if (balanceChanges.containsKey(phoneNumber)) {
            double currentBalance = (memberMap['balance'] ?? 0.0).toDouble();
            memberMap['balance'] =
                currentBalance + balanceChanges[phoneNumber]!;
          }

          return memberMap;
        }).toList();

        DocumentReference expenseRef = groupRef
            .collection('expenses')
            .doc(expenseId);

        var expenseData = {
          "title": title,
          "amount": amount,
          "paidBy": paidBy,
          "participants": participants,
          "updatedAt": FieldValue.serverTimestamp(),
        };

        transaction.update(expenseRef, expenseData);
        transaction.update(groupRef, {'members': updatedMembers});
      });

      // Update friend balances
      await _updateAllMemberBalances(groupId);

      // Update suggested settlements
      await SettlementService().updateSuggestedSettlements(groupId);

      await ActivityService().expenseEditedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseId: expenseId,
        expenseTitle: title,
        amount: amount,
        editedByPhone: currentUserPhone,
        editedByName: userName,
      );

      print('Expense edited, balances and settlements updated successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> deleteExpenseWithActivity({
    required String groupId,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference groupRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId);

        DocumentSnapshot groupSnapshot = await transaction.get(groupRef);

        if (!groupSnapshot.exists) {
          throw Exception('Group not found');
        }

        List<dynamic> members = groupSnapshot.get('members') ?? [];

        Map<String, double> balanceChanges = {};

        // Reverse balance changes
        paidBy.forEach((phoneNumber, amountPaid) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) - amountPaid;
        });

        participants.forEach((phoneNumber, amountOwed) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) + amountOwed;
        });

        List<Map<String, dynamic>> updatedMembers = members.map((member) {
          Map<String, dynamic> memberMap = Map<String, dynamic>.from(member);
          String phoneNumber = memberMap['phoneNumber'];

          if (balanceChanges.containsKey(phoneNumber)) {
            double currentBalance = (memberMap['balance'] ?? 0.0).toDouble();
            memberMap['balance'] =
                currentBalance + balanceChanges[phoneNumber]!;
          }

          return memberMap;
        }).toList();

        DocumentReference expenseRef = groupRef
            .collection('expenses')
            .doc(expenseId);
        transaction.delete(expenseRef);

        transaction.update(groupRef, {'members': updatedMembers});
      });

      // Update friend balances
      await _updateAllMemberBalances(groupId);

      // Update suggested settlements
      await SettlementService().updateSuggestedSettlements(groupId);

      await ActivityService().expenseDeletedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseTitle: expenseTitle,
        amount: amount,
        deletedByPhone: currentUserPhone,
        deletedByName: userName,
      );

      print('Expense deleted, balances and settlements updated successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> createGroupWithActivity({
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'You';

    try {
      final groupRef = await FirebaseFirestore.instance
          .collection('groups')
          .add({
            'groupName': groupName,
            'members': members,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': currentUserPhone,
          });

      await ActivityService().createGroupActivity(
        groupId: groupRef.id,
        groupName: groupName,
        creatorPhone: currentUserPhone,
        creatorName: userName,
      );

      print('Group and activity created successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  // Helper method to update friend balances
  Future<void> _updateAllMemberBalances(String groupId) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      print('Updating friend balances for ${members.length} members...');

      for (var member in members) {
        final memberPhone = member['phoneNumber'] as String;
        final memberGroups = await getMemberGroups(memberPhone);

        await FriendsBalanceService().recalculateUserFriendBalances(
          userPhone: memberPhone,
          groups: memberGroups,
        );
      }
    } catch (e) {
      print('Error updating member balances: $e');
    }
  }

  // Helper to get all groups a member belongs to
  Future<List<Map<String, dynamic>>> getMemberGroups(String memberPhone) async {
    try {
      final allGroupsSnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .get();

      final memberGroups = <Map<String, dynamic>>[];
      for (var doc in allGroupsSnapshot.docs) {
        final data = doc.data();
        final members = List<dynamic>.from(data['members'] ?? []);

        if (members.any((m) => m['phoneNumber'] == memberPhone)) {
          memberGroups.add({'id': doc.id, ...data});
        }
      }

      return memberGroups;
    } catch (e) {
      print('Error getting member groups: $e');
      return [];
    }
  }
}
