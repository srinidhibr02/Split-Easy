import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/activity_service.dart';

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
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {"id": doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> addExpenseWithActivity({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    // Get current user name and group name
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      // 1. Add the expense (your existing code)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        var expenseData = {
          "title": title,
          "amount": amount,
          "paidBy": paidBy,
          "participants": participants,
          "createdAt": FieldValue.serverTimestamp(),
        };

        // Use a batch write to ensure atomicity
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // 1. Add the expense document
        DocumentReference expenseRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('expenses')
            .doc(); // Creates a new document reference with auto-generated ID

        batch.set(expenseRef, expenseData);

        // 2. Calculate balances for each member
        // Balance = Amount paid - Amount owed
        Map<String, double> balanceChanges = {};

        // Add amounts paid by each payer
        paidBy.forEach((phoneNumber, amountPaid) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) + amountPaid;
        });

        // Subtract amounts owed by each participant
        participants.forEach((phoneNumber, amountOwed) {
          balanceChanges[phoneNumber] =
              (balanceChanges[phoneNumber] ?? 0) - amountOwed;
        });

        // 3. Update each member's balance in the group document
        DocumentReference groupRef = FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId);

        balanceChanges.forEach((phoneNumber, balanceChange) {
          // Update the specific member's balance in the members array
          batch.update(groupRef, {
            'members': FieldValue.arrayRemove([
              // This is a workaround - we'll need to fetch and update properly
            ]),
          });
        });

        // For proper member balance updates, we need to read the current state first
        DocumentSnapshot groupDoc = await groupRef.get();
        List<dynamic> members = groupDoc.get('members') ?? [];

        // Update each member's balance
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

        // Update the entire members array
        batch.update(groupRef, {'members': updatedMembers});

        // 4. Commit the batch
        await batch.commit();

        print('Expense added successfully and balances updated: $expenseData');
      });

      // 2. Create activity notification
      await ActivityService().expenseAddedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseId: 'expense_id', // Use actual expense ID from creation
        expenseTitle: title,
        amount: amount,
        addedByPhone: currentUserPhone,
        addedByName: userName,
        paidBy: paidBy,
        participants: participants,
      );

      print('Expense and activity created successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  // ============================================
  // 2. Add to your expense edit function
  // ============================================
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
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ... your existing expense edit code ...
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Reference to group document
          DocumentReference groupRef = FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId);

          // Read current group data
          DocumentSnapshot groupSnapshot = await transaction.get(groupRef);

          if (!groupSnapshot.exists) {
            throw Exception('Group not found');
          }

          List<dynamic> members = groupSnapshot.get('members') ?? [];

          // Step 1: Reverse the old balance changes
          Map<String, double> balanceChanges = {};

          // Reverse old: subtract amounts that were paid
          oldPaidBy.forEach((phoneNumber, amountPaid) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) - amountPaid;
          });

          // Reverse old: add back amounts that were owed
          oldParticipants.forEach((phoneNumber, amountOwed) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) + amountOwed;
          });

          // Step 2: Apply the new balance changes
          // Add new amounts paid by each payer
          paidBy.forEach((phoneNumber, amountPaid) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) + amountPaid;
          });

          // Subtract new amounts owed by each participant
          participants.forEach((phoneNumber, amountOwed) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) - amountOwed;
          });

          // Update members with net balance changes
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

          // Update expense document
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

          // Update group with new member balances
          transaction.update(groupRef, {'members': updatedMembers});
        });

        print('Expense edited successfully and balances adjusted');
      });

      // 2. Create activity notification
      await ActivityService().expenseEditedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseId: expenseId,
        expenseTitle: title,
        amount: amount,
        editedByPhone: currentUserPhone,
        editedByName: userName,
      );

      print('Expense edited and activity created');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  // ============================================
  // 3. Add to your expense delete function
  // ============================================
  Future<void> deleteExpenseWithActivity({
    required String groupId,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final groupName = groupDoc.data()?['groupName'] ?? 'Group';

    try {
      // 1. Delete the expense (your existing code)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Reference to group document
          DocumentReference groupRef = FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId);

          // Read current group data
          DocumentSnapshot groupSnapshot = await transaction.get(groupRef);

          if (!groupSnapshot.exists) {
            throw Exception('Group not found');
          }

          List<dynamic> members = groupSnapshot.get('members') ?? [];

          // Calculate balance changes to REVERSE
          // When deleting, we reverse the original operation
          Map<String, double> balanceChanges = {};

          // Reverse: subtract amounts that were paid
          paidBy.forEach((phoneNumber, amountPaid) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) - amountPaid;
          });

          // Reverse: add back amounts that were owed
          participants.forEach((phoneNumber, amountOwed) {
            balanceChanges[phoneNumber] =
                (balanceChanges[phoneNumber] ?? 0) + amountOwed;
          });

          // Update members with reversed balances
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

          // Delete expense document
          DocumentReference expenseRef = groupRef
              .collection('expenses')
              .doc(expenseId);
          transaction.delete(expenseRef);

          // Update group with reversed member balances
          transaction.update(groupRef, {'members': updatedMembers});
        });

        print('Expense deleted successfully and balances reversed');
      });

      await ActivityService().expenseDeletedActivity(
        groupId: groupId,
        groupName: groupName,
        expenseTitle: expenseTitle,
        amount: amount,
        deletedByPhone: currentUserPhone,
        deletedByName: userName,
      );

      print('Expense deleted and activity created');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> createGroupWithActivity({
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'You';

    try {
      // 1. Create the group
      final groupRef = await FirebaseFirestore.instance
          .collection('groups')
          .add({
            'groupName': groupName,
            'members': members,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': currentUserPhone,
          });

      // 2. Create activity notification
      await ActivityService().createGroupActivity(
        groupId: groupRef.id,
        groupName: groupName,
        creatorPhone: currentUserPhone,
        creatorName: userName,
      );

      print('Group and activity created successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> recordSettlementWithActivity({
    required String groupId,
    required String groupName,
    required String fromPhone,
    required String fromName,
    required String toPhone,
    required String toName,
    required double amount,
  }) async {
    final currentUserPhone =
        FirebaseAuth.instance.currentUser?.phoneNumber ?? "";

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'Someone';

    try {
      // 1. Record the settlement (create a balancing expense)
      // ... your settlement recording code ...

      // 2. Create activity notification
      await ActivityService().settlementRecordedActivity(
        groupId: groupId,
        groupName: groupName,
        fromPhone: fromPhone,
        fromName: fromName,
        toPhone: toPhone,
        toName: toName,
        amount: amount,
        recordedByPhone: currentUserPhone,
        recordedByName: userName,
      );

      print('Settlement and activity recorded');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }
}
