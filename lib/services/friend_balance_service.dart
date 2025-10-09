import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsBalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to reduce redundant queries
  final Map<String, Map<String, dynamic>> _groupCache = {};
  final Map<String, List<Map<String, dynamic>>> _settlementCache = {};

  /// Clear cache (call this when you want fresh data)
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

      // Use cache if available
      if (_settlementCache.containsKey(groupId)) {
        settlements = _settlementCache[groupId]!;
      } else {
        final settlementsSnapshot = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('suggestedSettlements')
            .get();

        settlements = settlementsSnapshot.docs
            .map((doc) => doc.data())
            .toList();
        _settlementCache[groupId] = settlements;
      }

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
  Future<void> updateFriendBalance({
    required String userPhone,
    required String friendPhone,
    required double balance,
    String? friendName,
    String? friendAvatar,
    String? userName,
    String? userAvatar,
  }) async {
    try {
      // Update in user's friends collection
      await _firestore
          .collection('users')
          .doc(userPhone)
          .collection('friends')
          .doc(friendPhone)
          .set({
            'phoneNumber': friendPhone,
            if (friendName != null) 'name': friendName,
            if (friendAvatar != null) 'avatar': friendAvatar,
            'balance': balance,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update reciprocal balance in friend's collection (opposite sign)
      await _firestore
          .collection('users')
          .doc(friendPhone)
          .collection('friends')
          .doc(userPhone)
          .set({
            'phoneNumber': userPhone,
            if (userName != null) 'name': userName,
            if (userAvatar != null) 'avatar': userAvatar,
            'balance': -balance, // Opposite perspective
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error updating friend balance: $e');
      rethrow; // Propagate error for proper handling
    }
  }

  /// Batch update friend balances for efficiency
  Future<void> _batchUpdateFriendBalances(
    List<Map<String, dynamic>> updates,
  ) async {
    if (updates.isEmpty) return;

    // Firestore batch has limit of 500 operations
    const batchSize = 250; // 250 pairs = 500 writes (user + friend)

    for (var i = 0; i < updates.length; i += batchSize) {
      final batch = _firestore.batch();
      final end = (i + batchSize < updates.length)
          ? i + batchSize
          : updates.length;
      final batchUpdates = updates.sublist(i, end);

      for (var update in batchUpdates) {
        // Update user's view
        final userRef = _firestore
            .collection('users')
            .doc(update['userPhone'])
            .collection('friends')
            .doc(update['friendPhone']);
        batch.set(userRef, update['userData'], SetOptions(merge: true));

        // Update friend's view
        final friendRef = _firestore
            .collection('users')
            .doc(update['friendPhone'])
            .collection('friends')
            .doc(update['userPhone']);
        batch.set(friendRef, update['friendData'], SetOptions(merge: true));
      }

      await batch.commit();
      print(
        '✅ Batch ${i ~/ batchSize + 1} committed (${batchUpdates.length} updates)',
      );
    }
  }

  /// Generate pair key for deduplication
  String _getPairKey(String phone1, String phone2) {
    final sorted = [phone1, phone2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get member data by phone number
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

  /// Recalculate balances for affected members in a specific group
  /// OPTIMIZED: Only recalculates balances between affected members
  Future<void> recalculateGroupFriendBalances({
    required String groupId,
    required List<String> affectedMemberPhones,
  }) async {
    try {
      print('🔄 Recalculating friend balances for group: $groupId');
      print('   Affected members: ${affectedMemberPhones.length}');

      // Clear cache to ensure fresh data
      clearCache();

      // Get the group data once
      final groupDoc = await _firestore.collection('groups').doc(groupId).get();

      if (!groupDoc.exists) {
        print('⚠️ Group not found: $groupId');
        return;
      }

      final groupData = groupDoc.data()!;
      final members = List<Map<String, dynamic>>.from(
        groupData['members'] ?? [],
      );

      // Create pairs of affected members
      // Only need to recalculate balances between members who were affected
      final processedPairs = <String>{};
      final updates = <Map<String, dynamic>>[];

      for (var i = 0; i < affectedMemberPhones.length; i++) {
        final memberPhone = affectedMemberPhones[i];
        final memberData = _getMemberData(members, memberPhone);

        if (memberData == null) {
          print('⚠️ Member not found in group: $memberPhone');
          continue;
        }

        // Get all groups this member is part of (cached after first fetch)
        final memberGroupsSnapshot = await _firestore
            .collection('groups')
            .where('memberPhones', arrayContains: memberPhone)
            .get();

        final memberGroups = memberGroupsSnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        // Process balance with other affected members
        for (var j = 0; j < affectedMemberPhones.length; j++) {
          if (i == j) continue; // Skip self

          final otherPhone = affectedMemberPhones[j];
          final pairKey = _getPairKey(memberPhone, otherPhone);

          // Skip if already processed this pair
          if (processedPairs.contains(pairKey)) continue;
          processedPairs.add(pairKey);

          final otherMemberData = _getMemberData(members, otherPhone);
          if (otherMemberData == null) {
            print('⚠️ Other member not found in group: $otherPhone');
            continue;
          }

          // Calculate balance between these two members across all their common groups
          final balance = await calculateFriendBalance(
            userPhone: memberPhone,
            friendPhone: otherPhone,
            groups: memberGroups,
          );

          // Prepare batch update
          updates.add({
            'userPhone': memberPhone,
            'friendPhone': otherPhone,
            'userData': {
              'phoneNumber': otherPhone,
              'name': otherMemberData['name'],
              'avatar': otherMemberData['avatar'] ?? '',
              'balance': balance,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
            'friendData': {
              'phoneNumber': memberPhone,
              'name': memberData['name'],
              'avatar': memberData['avatar'] ?? '',
              'balance': -balance,
              'lastUpdated': FieldValue.serverTimestamp(),
            },
          });
        }
      }

      // Batch update all friend balances
      if (updates.isNotEmpty) {
        await _batchUpdateFriendBalances(updates);
        print('✅ Friend balances updated: ${updates.length} relationships');
      } else {
        print('ℹ️ No friend balance updates needed');
      }

      // Clear cache after successful update
      clearCache();
    } catch (e) {
      print('❌ Error recalculating group friend balances: $e');
      clearCache(); // Clear cache on error too
      rethrow;
    }
  }

  /// Call this after adding an expense
  Future<void> onExpenseAdded({
    required String groupId,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    // All payers and participants are affected
    final affectedMembers = <String>{
      ...paidBy.keys,
      ...participants.keys,
    }.toList();

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  /// Call this after editing an expense
  Future<void> onExpenseEdited({
    required String groupId,
    required Map<String, double> oldPaidBy,
    required Map<String, double> oldParticipants,
    required Map<String, double> newPaidBy,
    required Map<String, double> newParticipants,
  }) async {
    // All members involved in old or new expense are affected
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

  /// Call this after deleting an expense
  Future<void> onExpenseDeleted({
    required String groupId,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    // All payers and participants are affected
    final affectedMembers = <String>{
      ...paidBy.keys,
      ...participants.keys,
    }.toList();

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  /// Call this after recording a settlement
  Future<void> onSettlementRecorded({
    required String groupId,
    required String fromPhone,
    required String toPhone,
  }) async {
    // Only the two members involved in the settlement are affected
    final affectedMembers = [fromPhone, toPhone];

    await recalculateGroupFriendBalances(
      groupId: groupId,
      affectedMemberPhones: affectedMembers,
    );
  }

  /// Recalculate balances for a specific user with all their friends
  /// Use this sparingly - only for initial setup or manual refresh
  Future<void> recalculateUserFriendBalances({
    required String userPhone,
    required List<Map<String, dynamic>> groups,
  }) async {
    try {
      print('🔄 Recalculating all friend balances for user: $userPhone');

      // Get all user's friends
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userPhone)
          .collection('friends')
          .get();

      final updates = <Map<String, dynamic>>[];

      for (var friendDoc in friendsSnapshot.docs) {
        final friendPhone = friendDoc.id;
        final friendData = friendDoc.data();

        // Recalculate balance using suggested settlements
        final balance = await calculateFriendBalance(
          userPhone: userPhone,
          friendPhone: friendPhone,
          groups: groups,
        );

        // Prepare batch update
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

      // Batch update all friend balances
      if (updates.isNotEmpty) {
        await _batchUpdateFriendBalances(updates);
        print('✅ All friend balances recalculated: ${updates.length} friends');
      }
    } catch (e) {
      print('❌ Error recalculating user friend balances: $e');
      rethrow;
    }
  }

  /// Stream friends with balances (real-time updates from stored data)
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

            // Only include friends with non-zero balance
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

          // Sort by absolute balance (highest first)
          friends.sort((a, b) {
            final balanceA = (a['balance'] as double).abs();
            final balanceB = (b['balance'] as double).abs();
            return balanceB.compareTo(balanceA);
          });

          return friends;
        });
  }

  /// Get total amount owed to user across all friends
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

  /// Get total amount user owes to others
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
