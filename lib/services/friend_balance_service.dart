import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsBalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to reduce redundant queries
  final Map<String, Map<String, dynamic>> _groupCache = {};
  final Map<String, List<Map<String, dynamic>>> _settlementCache = {};

  /// Clear cache (MUST be called after settlements are updated!)
  void clearCache() {
    _groupCache.clear();
    _settlementCache.clear();
  }

  Future<double> calculateFriendBalance({
    required String userPhone,
    required String friendPhone,
    required List<Map<String, dynamic>> groups,
  }) async {
    double totalBalance = 0.0;

    for (var group in groups) {
      // Check if both user and friend are in this group
      final members = List<Map<String, dynamic>>.from(group['members'] ?? []);
      final memberPhones = members
          .map((m) => m['phoneNumber'] as String)
          .toList();

      if (!memberPhones.contains(userPhone) ||
          !memberPhones.contains(friendPhone)) {
        continue;
      }

      // Get suggested settlements for this group
      final groupId = group['id'] as String;
      List<Map<String, dynamic>> settlements;

      // ALWAYS fetch fresh data from server (no cache) to avoid stale data
      final settlementsSnapshot = await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('suggestedSettlements')
          .get(const GetOptions(source: Source.server)); // Force server read

      settlements = settlementsSnapshot.docs.map((doc) => doc.data()).toList();

      for (var settlement in settlements) {
        final fromPhone = settlement['fromPhone'] as String;
        final toPhone = settlement['toPhone'] as String;
        final amount = (settlement['amount'] ?? 0).toDouble();

        // If friend owes user
        if (fromPhone == friendPhone && toPhone == userPhone) {
          totalBalance += amount;
        }
        // If user owes friend
        else if (fromPhone == userPhone && toPhone == friendPhone) {
          totalBalance -= amount;
        }
      }
    }

    return totalBalance;
  }

  /// Update friend's balance in Firestore
  Future<void> updateFriendBalances({
    required String fromPhone,
    required String toPhone,
    required double amount,
  }) async {
    final firestore = FirebaseFirestore.instance;

    final fromFriendRef = firestore
        .collection('users')
        .doc(fromPhone)
        .collection('friends')
        .doc(toPhone);

    final toFriendRef = firestore
        .collection('users')
        .doc(toPhone)
        .collection('friends')
        .doc(fromPhone);

    await firestore.runTransaction((transaction) async {
      final fromFriendSnap = await transaction.get(fromFriendRef);
      final toFriendSnap = await transaction.get(toFriendRef);

      final fromBalance =
          (fromFriendSnap.exists &&
              fromFriendSnap.data()!.containsKey('balance'))
          ? (fromFriendSnap.get('balance') as num).toDouble()
          : 0.0;

      final toBalance =
          (toFriendSnap.exists && toFriendSnap.data()!.containsKey('balance'))
          ? (toFriendSnap.get('balance') as num).toDouble()
          : 0.0;

      final newFromBalance = fromBalance + amount;
      final newToBalance = toBalance - amount;

      transaction.set(fromFriendRef, {
        'balance': newFromBalance,
      }, SetOptions(merge: true));
      transaction.set(toFriendRef, {
        'balance': newToBalance,
      }, SetOptions(merge: true));
    });

    print(
      'Updated friend balances for $fromPhone and $toPhone by amount $amount',
    );
  }

  /// Batch update friend balances
  Future<void> _batchUpdateFriendBalances(
    List<Map<String, dynamic>> updates,
  ) async {
    if (updates.isEmpty) return;

    const batchSize = 250;

    for (var i = 0; i < updates.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < updates.length)
          ? i + batchSize
          : updates.length;
      final batchUpdates = updates.sublist(i, end);

      for (var update in batchUpdates) {
        final userRef = _firestore
            .collection('users')
            .doc(update['userPhone'])
            .collection('friends')
            .doc(update['friendPhone']);
        batch.set(userRef, update['userData'], SetOptions(merge: true));

        final friendRef = _firestore
            .collection('users')
            .doc(update['friendPhone'])
            .collection('friends')
            .doc(update['userPhone']);
        batch.set(friendRef, update['friendData'], SetOptions(merge: true));
      }

      await batch.commit();
    }
  }

  String _getPairKey(String phone1, String phone2) {
    final sorted = [phone1, phone2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Map<String, dynamic>? _getMemberData(
    List<Map<String, dynamic>> members,
    String phone,
  ) {
    try {
      return members.firstWhere((m) => m['phoneNumber'] == phone);
    } catch (e) {
      return null;
    }
  }

  /// Recalculate balances for affected members
  Future<void> recalculateGroupFriendBalances({
    required String groupId,
    required List<String> affectedMemberPhones,
  }) async {
    try {
      print('🔄 Recalculating friend balances...');

      // CRITICAL: Clear cache at the start
      clearCache();

      // Get fresh group data from server
      final groupDoc = await _firestore
          .collection('groups')
          .doc(groupId)
          .get(const GetOptions(source: Source.server));

      if (!groupDoc.exists) {
        print('⚠️ Group not found');
        return;
      }

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      final processedPairs = <String>{};
      final updates = <Map<String, dynamic>>[];

      // For each affected member
      for (var affectedPhone in affectedMemberPhones) {
        final affectedMemberData = _getMemberData(members, affectedPhone);
        if (affectedMemberData == null) continue;

        // Get all groups for this member
        final memberGroupsSnapshot = await _firestore
            .collection('groups')
            .where('memberPhones', arrayContains: affectedPhone)
            .get(const GetOptions(source: Source.server)); // Force fresh data

        final memberGroups = memberGroupsSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        // Process with ALL other members in group
        for (var otherMember in members) {
          final otherPhone = otherMember['phoneNumber'] as String;
          if (otherPhone == affectedPhone) continue;

          final pairKey = _getPairKey(affectedPhone, otherPhone);
          if (processedPairs.contains(pairKey)) continue;
          processedPairs.add(pairKey);

          // Calculate with FRESH data
          final balance = await calculateFriendBalance(
            userPhone: affectedPhone,
            friendPhone: otherPhone,
            groups: memberGroups,
          );

          updates.add({
            'userPhone': affectedPhone,
            'friendPhone': otherPhone,
            'userData': {
              'phoneNumber': otherPhone,
              'name': otherMember['name'],
              'avatar': otherMember['avatar'] ?? '',
              'balance': balance,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            'friendData': {
              'phoneNumber': affectedPhone,
              'name': affectedMemberData['name'],
              'avatar': affectedMemberData['avatar'] ?? '',
              'balance': -balance,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
          });
        }
      }

      if (updates.isNotEmpty) {
        await _batchUpdateFriendBalances(updates);
        print('✅ Updated ${updates.length} friend relationships');
      }

      // Clear cache after update
      clearCache();
    } catch (e) {
      print('❌ Error recalculating: $e');
      clearCache();
      rethrow;
    }
  }

  Future<void> onExpenseAdded({
    required String groupId,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final affectedMembers = <String>{
      ...paidBy.keys,
      ...participants.keys,
    }.toList();

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  Future<void> onExpenseEdited({
    required String groupId,
    required Map<String, double> oldPaidBy,
    required Map<String, double> oldParticipants,
    required Map<String, double> newPaidBy,
    required Map<String, double> newParticipants,
  }) async {
    final affectedMembers = <String>{
      ...oldPaidBy.keys,
      ...oldParticipants.keys,
      ...newPaidBy.keys,
      ...newParticipants.keys,
    }.toList();

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  Future<void> onExpenseDeleted({
    required String groupId,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final affectedMembers = <String>{
      ...paidBy.keys,
      ...participants.keys,
    }.toList();

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  Future<void> onSettlementRecorded({
    required String groupId,
    required String fromPhone,
    required String toPhone,
    required double settlementAmount,
  }) async {
    await updateFriendBalances(
      fromPhone: fromPhone,
      toPhone: toPhone,
      amount: settlementAmount,
    );
  }

  Future<void> recalculateUserFriendBalances({
    required String userPhone,
    required List<Map<String, dynamic>> groups,
  }) async {
    try {
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userPhone)
          .collection('friends')
          .get();

      final updates = <Map<String, dynamic>>[];

      for (var friendDoc in friendsSnapshot.docs) {
        final friendPhone = friendDoc.id;
        final friendData = friendDoc.data();

        final balance = await calculateFriendBalance(
          userPhone: userPhone,
          friendPhone: friendPhone,
          groups: groups,
        );

        updates.add({
          'userPhone': userPhone,
          'friendPhone': friendPhone,
          'userData': {
            'phoneNumber': friendPhone,
            'name': friendData['name'],
            'avatar': friendData['avatar'] ?? '',
            'balance': balance,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          'friendData': {
            'phoneNumber': userPhone,
            'balance': -balance,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        });
      }

      if (updates.isNotEmpty) {
        await _batchUpdateFriendBalances(updates);
      }
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> streamFriendsWithBalances({
    required String userPhone,
  }) {
    return _firestore
        .collection('users')
        .doc(userPhone)
        .collection('friends')
        .snapshots()
        .map((snapshot) {
          final friends = <Map<String, dynamic>>[];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final balance = (data['balance'] ?? 0.0) as double;

            if (balance.abs() > 0.01) {
              friends.add({
                'phoneNumber': doc.id,
                'name': data['name'] ?? 'Unknown',
                'avatar': data['avatar'] ?? '',
                'balance': balance,
                'lastUpdated': data['lastUpdated'],
              });
            }
          }

          friends.sort((a, b) {
            final balanceA = (a['balance'] as double).abs();
            final balanceB = (b['balance'] as double).abs();
            return balanceB.compareTo(balanceA);
          });

          return friends;
        });
  }

  Future<double> getTotalOwedToUser(String userPhone) async {
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userPhone)
        .collection('friends')
        .get();

    double total = 0.0;
    for (var doc in friendsSnapshot.docs) {
      final balance = (doc.data()['balance'] ?? 0.0) as double;
      if (balance > 0) {
        total += balance;
      }
    }
    return total;
  }

  Future<double> getTotalUserOwes(String userPhone) async {
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userPhone)
        .collection('friends')
        .get();

    double total = 0.0;
    for (var doc in friendsSnapshot.docs) {
      final balance = (doc.data()['balance'] ?? 0.0) as double;
      if (balance < 0) {
        total += balance.abs();
      }
    }
    return total;
  }
}
