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
  final FriendsBalanceService _friendsBalanceService = FriendsBalanceService();

  Future<void> _updateAllMemberBalances(String groupId) async {
    try {
      // Get group data
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      print('🔄 Updating balances for ${members.length} members...');

      // For each member, get their groups and recalculate friend balances
      for (var member in members) {
        final memberPhone = member['phoneNumber'] as String;

        // Get all groups this member is part of
        final memberGroups = await groupService.getMemberGroups(memberPhone);

        print('✅ Updated balances for $memberPhone');
      }
    } catch (e) {
      print('❌ Error updating member balances: $e');
    }
  }

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
      await SettlementService().updateSuggestedSettlements(groupId);
      await Future.delayed(const Duration(milliseconds: 500));

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
      await Future.delayed(const Duration(milliseconds: 500));

      // Background tasks
      await SettlementService().updateSuggestedSettlements(groupId);
      await Future.delayed(const Duration(milliseconds: 500));

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
}

// Singleton instance
final expenseService = ExpenseService();
