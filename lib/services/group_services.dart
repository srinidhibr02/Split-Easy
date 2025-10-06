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

  /// Stream a single group by ID
  Stream<Map<String, dynamic>> streamGroupById(String groupId) {
    return _firestore.collection("groups").doc(groupId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return {};
      final data = snapshot.data()!;
      data["id"] = snapshot.id;
      return data;
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
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {"id": doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Get user and group names in one batch read
  Future<Map<String, String>> _getUserAndGroupNames(
    String userPhone,
    String groupId,
  ) async {
    final batch = await Future.wait([
      _firestore.collection('users').doc(userPhone).get(),
      _firestore.collection('groups').doc(groupId).get(),
    ]);

    return {
      'userName': batch[0].data()?['name'] ?? 'Someone',
      'groupName': batch[1].data()?['groupName'] ?? 'Group',
    };
  }

  Future<void> addExpenseWithActivity({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    // Single batched read instead of 2 separate reads
    final names = await _getUserAndGroupNames(currentUserPhone, groupId);

    try {
      String? expenseId;

      await _firestore.runTransaction((transaction) async {
        final groupRef = _firestore.collection('groups').doc(groupId);
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

      await SettlementService().updateSuggestedSettlements(groupId);
      await _updateAllMemberBalances(groupId);

      await ActivityService().expenseAddedActivity(
        groupId: groupId,
        groupName: names['groupName']!,
        expenseId: expenseId ?? 'unknown',
        expenseTitle: title,
        amount: amount,
        addedByPhone: currentUserPhone,
        addedByName: names['userName']!,
        paidBy: paidBy,
        participants: participants,
      );

      print('Expense created successfully');
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
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    // Single batched read
    final names = await _getUserAndGroupNames(currentUserPhone, groupId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference groupRef = _firestore
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

      // Background tasks
      await SettlementService().updateSuggestedSettlements(groupId);
      await _updateAllMemberBalances(groupId);

      await ActivityService().expenseEditedActivity(
        groupId: groupId,
        groupName: names['groupName']!,
        expenseId: expenseId,
        expenseTitle: title,
        amount: amount,
        editedByPhone: currentUserPhone,
        editedByName: names['userName']!,
      );

      print('Expense edited successfully');
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
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    // Single batched read
    final names = await _getUserAndGroupNames(currentUserPhone, groupId);

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference groupRef = _firestore
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

      // Background tasks
      await SettlementService().updateSuggestedSettlements(groupId);
      await _updateAllMemberBalances(groupId);

      await ActivityService().expenseDeletedActivity(
        groupId: groupId,
        groupName: names['groupName']!,
        expenseTitle: expenseTitle,
        amount: amount,
        deletedByPhone: currentUserPhone,
        deletedByName: names['userName']!,
      );

      print('Expense deleted successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> createGroupWithActivity({
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) async {
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'You';

    try {
      final groupRef = await _firestore.collection('groups').add({
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

      print('Group created successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  /// Add member to group
  Future<void> addMemberToGroup({
    required String groupId,
    required String newMemberPhone,
    required String addedByPhone,
  }) async {
    try {
      final groupRef = _firestore.collection('groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      // Check if member already exists
      if (members.any((m) => m['phoneNumber'] == newMemberPhone)) {
        throw Exception('Member already exists in group');
      }

      // Get new member data
      final memberDoc = await _firestore
          .collection('users')
          .doc(newMemberPhone)
          .get();
      if (!memberDoc.exists) {
        throw Exception('User not found');
      }

      final memberData = memberDoc.data()!;
      final newMember = {
        'phoneNumber': newMemberPhone,
        'name': memberData['name'] ?? 'Unknown',
        'avatar': memberData['avatar'] ?? '',
        'balance': 0.0,
      };

      members.add(newMember);

      await groupRef.update({'members': members});

      print('Member added successfully');
    } catch (e) {
      print('Error adding member: $e');
      rethrow;
    }
  }

  // Helper method to update friend balances
  Future<void> _updateAllMemberBalances(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      for (var member in members) {
        final memberPhone = member['phoneNumber'] as String;
        final memberGroups = await getMemberGroups(memberPhone);

        FriendsBalanceService().recalculateUserFriendBalances(
          userPhone: memberPhone,
          groups: memberGroups,
        );
      }
    } catch (e) {
      print('Error updating member balances: $e');
    }
  }

  // Cache for member groups to reduce reads
  final Map<String, List<Map<String, dynamic>>> _memberGroupsCache = {};

  Future<List<Map<String, dynamic>>> getMemberGroups(String memberPhone) async {
    // Check cache first
    if (_memberGroupsCache.containsKey(memberPhone)) {
      return _memberGroupsCache[memberPhone]!;
    }

    try {
      final allGroupsSnapshot = await _firestore.collection('groups').get();

      final memberGroups = <Map<String, dynamic>>[];
      for (var doc in allGroupsSnapshot.docs) {
        final data = doc.data();
        final members = List<dynamic>.from(data['members'] ?? []);

        if (members.any((m) => m['phoneNumber'] == memberPhone)) {
          memberGroups.add({'id': doc.id, ...data});
        }
      }

      // Cache for 30 seconds
      _memberGroupsCache[memberPhone] = memberGroups;
      Future.delayed(const Duration(seconds: 30), () {
        _memberGroupsCache.remove(memberPhone);
      });

      return memberGroups;
    } catch (e) {
      print('Error getting member groups: $e');
      return [];
    }
  }
}
