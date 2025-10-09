import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/dataModels/dataModels.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/settlement_calculator.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FriendsBalanceService _friendsBalanceService = FriendsBalanceService();

  static List<Settlement> calculateSettlements(Map<String, dynamic> group) {
    final members =
        (group["members"] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    List<Map<String, dynamic>> debtors = [];
    List<Map<String, dynamic>> creditors = [];

    for (var member in members) {
      final balance = (member["balance"] ?? 0.0).toDouble();
      final memberData = {
        "phoneNumber": member["phoneNumber"],
        "name": member["name"],
        "balance": balance.abs(),
      };
      if (balance < -0.01) {
        debtors.add(memberData);
      } else if (balance > 0.01) {
        creditors.add(memberData);
      }
    }

    debtors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );
    creditors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );

    List<Settlement> settlements = [];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor["balance"] as double;
      final creditAmount = creditor["balance"] as double;
      final settleAmount = debtAmount < creditAmount
          ? debtAmount
          : creditAmount;

      settlements.add(
        Settlement(
          fromPhone: debtor["phoneNumber"],
          fromName: debtor["name"],
          toPhone: creditor["phoneNumber"],
          toName: creditor["name"],
          amount: settleAmount,
        ),
      );

      debtor["balance"] = debtAmount - settleAmount;
      creditor["balance"] = creditAmount - settleAmount;

      if (debtor["balance"] < 0.01) i++;
      if (creditor["balance"] < 0.01) j++;
    }
    return settlements;
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

        final activityRef = groupRef.collection('settlements').doc();
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

      // Add delay to ensure Firestore propagation
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Update friend balances for ALL group members
      await _updateAllMemberBalances(groupId);

      // Step 3: Recalculate and store new suggested settlements
      await updateSuggestedSettlements(groupId);

      print('Settlement recorded and friend balances updated');

      ActivityService().recordSettlementActivity(
        groupId: groupId,
        fromPhone: fromPhone,
        toPhone: toPhone,
        amount: amount,
        fromName: fromName,
        toName: toName,
      );
    } catch (e) {
      throw Exception('Failed to record settlement: $e');
    }
  }

  /// Update suggested settlements in Firestore with fresh data
  Future<void> updateSuggestedSettlements(String groupId) async {
    try {
      // Use get() with source: Source.server to force fresh data from server
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get(const GetOptions(source: Source.server));

      if (!groupDoc.exists) {
        print('Group not found: $groupId');
        return;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;

      // Calculate settlements with fresh data
      final suggestions = SettlementCalculator.calculateSettlements(groupData);

      await storeSuggestedSettlements(
        groupId: groupId,
        settlements: suggestions,
      );

      print(
        '✅ Suggested settlements updated for group: $groupId (${suggestions.length} settlements)',
      );
    } catch (e) {
      print('❌ Error updating suggested settlements: $e');
      rethrow;
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
      rethrow;
    }
  }

  /// Update friend balances for all members in the group
  Future<void> _updateAllMemberBalances(String groupId) async {
    try {
      // Force server fetch to get latest data
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get(const GetOptions(source: Source.server));

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
