import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/dataModels/dataModels.dart';
import 'package:split_easy/screens/settlement.dart';
import 'package:split_easy/services/friend_balance_service.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendsBalanceService _friendsBalanceService = FriendsBalanceService();

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

      // Step 1: Update group member balances and add settlement document
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

        final activityRef = groupRef.collection('activity').doc();
        transaction.set(activityRef, {
          'type': 'settlement',
          'fromPhone': fromPhone,
          'fromName': fromName,
          'toPhone': toPhone,
          'toName': toName,
          'amount': amount,
          'message': '$fromName paid $toName ₹${amount.toStringAsFixed(2)}',
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': DateTime.now().toIso8601String(),
        });
      });

      // Step 2: Update friend balances for ALL group members
      await _updateAllMemberBalances(groupId);

      // Step 3: Recalculate and store new suggested settlements
      final updatedGroup = await _firestore
          .collection('groups')
          .doc(groupId)
          .get();
      if (updatedGroup.exists) {
        final groupData = updatedGroup.data() as Map<String, dynamic>;
        final newSuggestions = SettlementCalculator.calculateSettlements(
          groupData,
        );
        await storeSuggestedSettlements(
          groupId: groupId,
          settlements: newSuggestions,
        );
      }

      print('Settlement recorded and friend balances updated');
    } catch (e) {
      throw Exception('Failed to record settlement: $e');
    }
  }

  /// Update suggested settlements in Firestore
  Future<void> updateSuggestedSettlements(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final suggestions = SettlementCalculator.calculateSettlements(groupData);

      await storeSuggestedSettlements(
        groupId: groupId,
        settlements: suggestions,
      );

      print('✅ Suggested settlements updated for group: $groupId');
    } catch (e) {
      print('❌ Error updating suggested settlements: $e');
    }
  }

  /// Store suggested settlements for a group
  Future<void> storeSuggestedSettlements({
    required String groupId,
    required List<Settlement> settlements,
  }) async {
    try {
      final batch = _firestore.batch();
      final suggestedRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('suggestedSettlements');

      // Delete old suggested settlements first
      final oldSettlements = await suggestedRef.get();
      for (var doc in oldSettlements.docs) {
        batch.delete(doc.reference);
      }

      // Add new suggested settlements
      for (var settlement in settlements) {
        final docRef = suggestedRef.doc();
        batch.set(docRef, {
          'fromPhone': settlement.fromPhone,
          'fromName': settlement.fromName,
          'toPhone': settlement.toPhone,
          'toName': settlement.toName,
          'amount': settlement.amount,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Stored ${settlements.length} suggested settlements');
    } catch (e) {
      print('Error storing suggested settlements: $e');
    }
  }

  /// Update friend balances for all members in the group
  Future<void> _updateAllMemberBalances(String groupId) async {
    try {
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      if (!groupDoc.exists) return;

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      print('Updating friend balances for ${members.length} members...');

      for (var member in members) {
        final memberPhone = member['phoneNumber'] as String;

        // Get all groups this member is part of
        final memberGroups = await _getMemberGroups(memberPhone);

        // Recalculate balances with all their friends
        await _friendsBalanceService.recalculateUserFriendBalances(
          userPhone: memberPhone,
          groups: memberGroups,
        );
      }
    } catch (e) {
      print('Error updating member balances: $e');
    }
  }

  /// Get all groups a member belongs to
  Future<List<Map<String, dynamic>>> _getMemberGroups(
    String memberPhone,
  ) async {
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

      return memberGroups;
    } catch (e) {
      print('Error getting member groups: $e');
      return [];
    }
  }
}
