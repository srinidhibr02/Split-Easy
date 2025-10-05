import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/group_services.dart';

/// Service that wraps expense operations and automatically updates friend balances
/// Use this instead of direct Firestore calls to ensure balances stay in sync
class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GroupService groupService = GroupService();
  final FriendsBalanceService _friendsBalanceService = FriendsBalanceService();

  /// Add expense and update all group members' friend balances
  Future<void> addExpense({
    required String groupId,
    required Map<String, dynamic> expenseData,
  }) async {
    try {
      // Add the expense
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .add(expenseData);

      // Update balances for ALL group members (even offline ones)
      await _updateAllMemberBalances(groupId);

      print('✅ Expense added and balances updated for all members');
    } catch (e) {
      print('❌ Error adding expense: $e');
      rethrow;
    }
  }

  /// Update expense and recalculate balances
  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required Map<String, dynamic> expenseData,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .update(expenseData);

      await _updateAllMemberBalances(groupId);

      print('✅ Expense updated and balances recalculated');
    } catch (e) {
      print('❌ Error updating expense: $e');
      rethrow;
    }
  }

  /// Delete expense and recalculate balances
  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      await _updateAllMemberBalances(groupId);

      print('✅ Expense deleted and balances recalculated');
    } catch (e) {
      print('❌ Error deleting expense: $e');
      rethrow;
    }
  }

  /// Add settlement and update balances
  Future<void> addSettlement({
    required String groupId,
    required String fromPhone,
    required String toPhone,
    required double amount,
  }) async {
    try {
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .add({
            'fromPhone': fromPhone,
            'toPhone': toPhone,
            'amount': amount,
            'timestamp': FieldValue.serverTimestamp(),
          });

      await _updateAllMemberBalances(groupId);

      print('✅ Settlement recorded and balances updated');
    } catch (e) {
      print('❌ Error adding settlement: $e');
      rethrow;
    }
  }

  /// Update balances for ALL members in a group
  /// This ensures even offline users get updated balances in Firestore
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

        // Recalculate balances with all their friends across all groups
        await _friendsBalanceService.recalculateUserFriendBalances(
          userPhone: memberPhone,
          groups: memberGroups,
        );

        print('✅ Updated balances for $memberPhone');
      }
    } catch (e) {
      print('❌ Error updating member balances: $e');
    }
  }

  /// Get all groups a member belongs to
}

// Singleton instance
final expenseService = ExpenseService();
