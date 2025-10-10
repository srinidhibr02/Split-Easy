import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/dataModels/data_models.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/settlement_calculator.dart';

class SettlementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Calculate settlements using SettlementCalculator
  static List<Settlement> calculateSettlements(Map<String, dynamic> group) {
    return SettlementCalculator.calculateSettlements(group);
  }

  /// Validate settlement before recording
  void _validateSettlement({
    required String fromPhone,
    required String toPhone,
    required double amount,
    required Map<String, dynamic> groupData,
  }) {
    if (amount <= 0) {
      throw ArgumentError('Settlement amount must be positive');
    }

    if (fromPhone == toPhone) {
      throw ArgumentError('Cannot settle with yourself');
    }

    final members = List<Map<String, dynamic>>.from(
      groupData['members'] as List<dynamic>,
    );
    final memberPhones = members
        .map((m) => m['phoneNumber'] as String)
        .toList();

    if (!memberPhones.contains(fromPhone)) {
      throw ArgumentError('Payer ($fromPhone) not found in group');
    }

    if (!memberPhones.contains(toPhone)) {
      throw ArgumentError('Recipient ($toPhone) not found in group');
    }
  }

  /// Check for duplicate settlements
  Future<bool> _isDuplicateSettlement({
    required String groupId,
    required String fromPhone,
    required String toPhone,
    required double amount,
  }) async {
    try {
      final recentSettlements = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('settlements')
          .where('fromPhone', isEqualTo: fromPhone)
          .where('toPhone', isEqualTo: toPhone)
          .where('amount', isEqualTo: amount)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (recentSettlements.docs.isNotEmpty) {
        final lastSettlement = recentSettlements.docs.first;
        final timestamp = lastSettlement.data()['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inSeconds < 5) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Warning: Could not check for duplicate settlements: $e');
      return false;
    }
  }

  /// Record a settlement between two members
  Future<void> recordSettlement({
    required String groupId,
    required String fromPhone,
    required String toPhone,
    required double amount,
    required String fromName,
    required String toName,
  }) async {
    try {
      print(
        '📝 Recording settlement: $fromName → $toName: ₹${amount.toStringAsFixed(2)}',
      );

      final groupRef = _firestore.collection('groups').doc(groupId);

      // Pre-fetch group data for validation
      final groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists) {
        throw Exception('Group not found');
      }

      final groupData = groupSnapshot.data() as Map<String, dynamic>;

      // Validate settlement
      _validateSettlement(
        fromPhone: fromPhone,
        toPhone: toPhone,
        amount: amount,
        groupData: groupData,
      );

      // Check for duplicates
      final isDuplicate = await _isDuplicateSettlement(
        groupId: groupId,
        fromPhone: fromPhone,
        toPhone: toPhone,
        amount: amount,
      );

      if (isDuplicate) {
        print('⚠️ Duplicate settlement detected, skipping');
        return;
      }

      // Step 1: Update group member balances and add settlement document in transaction
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
          throw Exception('One or both members not found in group');
        }

        transaction.update(groupRef, {'members': members});

        final settlementRef = groupRef.collection('settlements').doc();
        transaction.set(settlementRef, {
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

        print(
          '✅ Transaction completed: balances updated and settlement recorded',
        );
      });

      // Step 2: Update suggested settlements
      print('🔄 Updating suggested settlements...');
      await updateSuggestedSettlements(groupId);
      print('✅ Suggested settlements updated');

      // Step 3: CRITICAL FIX - Clear friend service cache BEFORE recalculating
      print('🔄 Clearing friend service cache...');
      FriendsBalanceService().clearCache();

      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Update friend balances with fresh data
      print('🔄 Updating friend balances...');
      await FriendsBalanceService().onSettlementRecorded(
        groupId: groupId,
        fromPhone: fromPhone,
        toPhone: toPhone,
        settlementAmount: amount,
      );
      print('✅ Friend balances updated');

      // Step 5: Record activity
      print('🔄 Recording activity...');
      await ActivityService().recordSettlementActivity(
        groupId: groupId,
        fromPhone: fromPhone,
        toPhone: toPhone,
        amount: amount,
        fromName: fromName,
        toName: toName,
      );
      print('✅ Activity recorded');

      print('🎉 Settlement recorded successfully');
    } catch (e) {
      print('❌ Failed to record settlement: $e');
      throw Exception('Failed to record settlement: $e');
    }
  }

  /// Update suggested settlements in Firestore with fresh data
  Future<void> updateSuggestedSettlements(String groupId) async {
    try {
      // Force fresh data from server
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get(const GetOptions(source: Source.server));

      if (!groupDoc.exists) {
        print('⚠️ Group not found: $groupId');
        return;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;

      // Validate balances sum to zero
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] as List<dynamic>? ?? [],
      );

      double totalBalance = 0.0;
      for (var member in members) {
        totalBalance += (member['balance'] ?? 0.0) as num;
      }

      if (totalBalance.abs() > 0.01) {
        print(
          '⚠️ WARNING: Group $groupId balances do not sum to zero! Total: ${totalBalance.toStringAsFixed(2)}',
        );
      }

      // Calculate settlements with fresh data
      final suggestions = SettlementCalculator.calculateSettlements(groupData);

      // Store the new suggestions
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
      print('✅ Stored ${settlements.length} suggested settlements');
    } catch (e) {
      print('❌ Error storing suggested settlements: $e');
      rethrow;
    }
  }

  /// Get settlement history for a group
  Stream<List<Map<String, dynamic>>> streamSettlementHistory(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('settlements')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Get suggested settlements for a group
  Stream<List<Settlement>> streamSuggestedSettlements(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('suggestedSettlements')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return Settlement(
              fromPhone: data['fromPhone'] as String,
              fromName: data['fromName'] as String,
              toPhone: data['toPhone'] as String,
              toName: data['toName'] as String,
              amount: (data['amount'] as num).toDouble(),
            );
          }).toList();
        });
  }
}
