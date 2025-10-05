import 'package:cloud_firestore/cloud_firestore.dart';

class FriendsBalanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final settlementsSnapshot = await _firestore
          .collection('groups')
          .doc(group['id'])
          .collection('suggestedSettlements')
          .get();

      for (var doc in settlementsSnapshot.docs) {
        final settlement = doc.data();
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
            'balance': -balance, // Opposite perspective
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating friend balance: $e');
    }
  }

  /// Get user data (name, avatar)
  Future<Map<String, dynamic>> _getUserData(String phoneNumber) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(phoneNumber)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'name': data['name'] ?? 'Unknown',
          'avatar': data['avatar'] ?? '',
        };
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return {'name': 'Unknown', 'avatar': ''};
  }

  /// Recalculate balances for a specific user with all their friends
  Future<void> recalculateUserFriendBalances({
    required String userPhone,
    required List<Map<String, dynamic>> groups,
  }) async {
    try {
      // Get all user's friends
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userPhone)
          .collection('friends')
          .get();

      for (var friendDoc in friendsSnapshot.docs) {
        final friendPhone = friendDoc.id;
        final friendData = friendDoc.data();

        // Recalculate balance using suggested settlements
        final balance = await calculateFriendBalance(
          userPhone: userPhone,
          friendPhone: friendPhone,
          groups: groups,
        );

        // Update stored balance
        await updateFriendBalance(
          userPhone: userPhone,
          friendPhone: friendPhone,
          balance: balance,
          friendName: friendData['name'],
          friendAvatar: friendData['avatar'],
        );
      }
    } catch (e) {
      print('Error recalculating user friend balances: $e');
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
}
