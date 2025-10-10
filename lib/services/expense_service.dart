import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/group_services.dart';
import 'package:split_easy/services/settlement_service.dart';

class ExpenseService {
  final AuthServices _auth = AuthServices();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService groupService = GroupService();
  final FriendsBalanceService friendsBalanceService = FriendsBalanceService();

  Future<void> addExpenseWithActivity({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    final names = await groupService.getUserAndGroupNames(
      currentUserPhone,
      groupId,
    );
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

      await Future.delayed(const Duration(milliseconds: 500));

      await SettlementService().updateSuggestedSettlements(groupId);

      await Future.delayed(const Duration(milliseconds: 500));

      FriendsBalanceService().onExpenseAdded(
        groupId: groupId,
        paidBy: paidBy,
        participants: participants,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      ActivityService().expenseAddedActivity(
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
    } catch (e) {
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
    final names = await groupService.getUserAndGroupNames(
      currentUserPhone,
      groupId,
    );

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
      await Future.delayed(const Duration(milliseconds: 500));

      // Background tasks
      SettlementService().updateSuggestedSettlements(groupId);

      await Future.delayed(const Duration(milliseconds: 500));

      FriendsBalanceService().onExpenseEdited(
        groupId: groupId,
        oldPaidBy: oldPaidBy,
        oldParticipants: oldParticipants,
        newPaidBy: paidBy,
        newParticipants: participants,
      );

      await ActivityService().expenseEditedActivity(
        groupId: groupId,
        groupName: names['groupName']!,
        expenseId: expenseId,
        expenseTitle: title,
        amount: amount,
        editedByPhone: currentUserPhone,
        editedByName: names['userName']!,
      );
    } catch (e) {
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
    final names = await groupService.getUserAndGroupNames(
      currentUserPhone,
      groupId,
    );

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

        // Reverse balance changes (subtract what was paid, add back what was owed)
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

        // Delete expense and update members in transaction
        DocumentReference expenseRef = groupRef
            .collection('expenses')
            .doc(expenseId);
        transaction.delete(expenseRef);
        transaction.update(groupRef, {'members': updatedMembers});
      });

      // Wait for Firestore propagation
      await Future.delayed(const Duration(milliseconds: 500));

      // Background tasks after transaction completes
      SettlementService().updateSuggestedSettlements(groupId);

      await FriendsBalanceService().onExpenseDeleted(
        groupId: groupId,
        paidBy: paidBy,
        participants: participants,
      );

      await Future.delayed(const Duration(milliseconds: 500));

      await ActivityService().expenseDeletedActivity(
        groupId: groupId,
        groupName: names["groupName"] as String,
        expenseTitle: expenseTitle,
        amount: amount,
        deletedByPhone: currentUserPhone,
        deletedByName: names["userName"] as String,
      );
    } catch (e) {
      rethrow;
    }
  }
}

// Singleton instance
final expenseService = ExpenseService();
