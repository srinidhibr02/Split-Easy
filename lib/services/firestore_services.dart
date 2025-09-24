import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirestoreServices {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentPhoneNumber => _auth.currentUser?.phoneNumber;

  DocumentReference getUserDoc(User user) {
    return _fireStore.collection("users").doc(user.phoneNumber);
  }

  Stream<Map<String, dynamic>?> streamUserProfile(User user) {
    return getUserDoc(user).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>;
    });
  }

  Future<void> updateUserProfile(User user, Map<String, dynamic> data) async {
    await getUserDoc(user).update(data);
  }

  Future<void> createUserInFireStore(User? user) async {
    if (user == null) return;
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        "phoneNumber": user.phoneNumber,
        "createdAt": FieldValue.serverTimestamp(),
        "isProfileCompleted": false, // you can use this later
      });
    }
  }

  Future<bool> isProfileCompleted(User? user) async {
    if (user == null) return false;
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);
    final docSnapshot = await userDoc.get();
    return docSnapshot.data()?["isProfileCompleted"] ?? false;
  }

  Future<void> updateUserInfo({
    required User? user,
    required String userName,
    required String avatar,
  }) async {
    if (user == null) return;
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);
    await userDoc.set({
      "name": userName,
      "avatar": avatar,
      "isProfileCompleted": true,
    });
  }

  Future<void> createGroup({
    required String groupName,
    required String purpose,
  }) async {
    final userDoc = _fireStore.collection("users").doc(currentPhoneNumber);

    // Get user data
    final userSnapshot = await userDoc.get();
    final userData = userSnapshot.exists ? userSnapshot.data()! : {};
    final userName = userData["name"] ?? "Unknown";
    final userAvatar = userData["avatar"] ?? "default_avatar_url";

    // Create a new group in the global 'groups' collection
    final newGroupDoc = await _fireStore.collection("groups").add({
      "groupName": groupName,
      "purpose": purpose,
      "createdAt": FieldValue.serverTimestamp(),
      "owner": {
        "phoneNumber": currentPhoneNumber,
        "name": userName,
        "avatar": userAvatar,
      },
      "members": [
        {
          "phoneNumber": currentPhoneNumber,
          "name": userName,
          "avatar": userAvatar,
        },
      ],
    });

    final groupId = newGroupDoc.id;

    // Add groupId to the owner's 'groups' array
    await userDoc.update({
      "groups": FieldValue.arrayUnion([groupId]),
    });

    print("Group '$groupName' created successfully with ID: $groupId");
  }

  Stream<Map<String, dynamic>?> streamGroupById(String groupId) {
    return _fireStore.collection("groups").doc(groupId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return null;
      return {"id": snapshot.id, ...snapshot.data()!};
    });
  }

  Stream<List<Map<String, dynamic>>> streamUserGroups(User user) {
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);

    return userDoc.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return [];

      final groupIds = List<String>.from(snapshot.data()?["groups"] ?? []);

      if (groupIds.isEmpty) return [];

      // Fetch all group documents for these IDs
      final groupsQuery = await _fireStore
          .collection("groups")
          .where(FieldPath.documentId, whereIn: groupIds)
          .get();

      return groupsQuery.docs
          .map((doc) => {"id": doc.id, ...doc.data()})
          .toList();
    });
  }

  Future<void> addMemberToGroup({
    required String groupId,
    required String newMemberPhoneNumber,
  }) async {
    final groupDoc = _fireStore.collection("groups").doc(groupId);
    final newMemberDoc = _fireStore
        .collection("users")
        .doc(newMemberPhoneNumber);

    // Get group data
    final groupSnapshot = await groupDoc.get();
    if (!groupSnapshot.exists) {
      print("Group not found");
      return;
    }
    final groupData = groupSnapshot.data()!;

    // Get new member data
    final newMemberSnapshot = await newMemberDoc.get();
    final newMemberData = newMemberSnapshot.exists
        ? newMemberSnapshot.data()!
        : {"name": "Unknown", "avatar": "default_avatar_url"};

    final newMemberInfo = {
      "phoneNumber": newMemberPhoneNumber,
      "name": newMemberData["name"],
      "avatar": newMemberData["avatar"],
    };

    // 1️⃣ Add member to group's members array
    await groupDoc.update({
      "members": FieldValue.arrayUnion([newMemberInfo]),
    });

    // 2️⃣ Add groupId to new member's groups array
    await newMemberDoc.update({
      "groups": FieldValue.arrayUnion([groupId]),
    });

    print(
      "${newMemberData["name"]} added to group '${groupData["groupName"]}'",
    );
  }

  //Stream of friends for the current User
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    final phone = currentPhoneNumber;

    if (phone == null) {
      throw Exception("No user logged in");
    }
    final userDoc = _fireStore.collection("users").doc(phone);

    return userDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final friends = snapshot.data()?["friends"] as List<dynamic>?;
      return friends != null
          ? friends.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    });
  }

  //adds expence to a group and updates balances for each member
  Future<void> addExpenseToGroup({
    required String groupName,
    required String title,
    required double amount,
    required List<String> paidBy,
    required List<String> participants,
    required Map<String, double> splits,
    required Map<String, double> contributions,
    required String splitType, //equally | unequally
  }) async {
    final batch = _fireStore.batch();

    try {
      //prepare expense data
      final expenseRef = _fireStore.collection("tmp").doc(); //just for id
      final expenseId = expenseRef.id;

      final expenseData = {
        "id": expenseId,
        "title": title,
        "amount": amount,
        "paidBy": paidBy,
        "participants": participants,
        "contributions": contributions,
        "splits": splits,
        "splitType": splitType,
        "createdAt": FieldValue.serverTimestamp(),
      };
      for (final member in participants) {
        final expenseDocRef = _fireStore
            .collection("users")
            .doc(member)
            .collection("groups")
            .doc(groupName)
            .collection("expenses")
            .doc(expenseId);

        batch.set(expenseDocRef, expenseData);

        //optional also update group's lastupdated field
        final groupDocRef = _fireStore
            .collection("users")
            .doc(member)
            .collection("groups")
            .doc(groupName);
        batch.set(groupDocRef, {
          "lastExpense": {
            "title": title,
            "amount": amount,
            "createdAt": FieldValue.serverTimestamp(),
          },
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      //step 2 update balance inside friends subcollection
      for (final participant in participants) {
        final owed = splits[participant] ?? 0;
        for (final payer in paidBy) {
          if (participant == payer) continue;
          final paidShare = (contributions[payer] ?? 0) * (owed / amount);

          final payerFriendRef = _fireStore
              .collection("users")
              .doc(payer)
              .collection("friends")
              .doc(participant);

          final participantFriendRef = _fireStore
              .collection("users")
              .doc(participant)
              .collection("friends")
              .doc(payer);

          //payer side (+balance)
          batch.set(payerFriendRef, {
            "phoneNumber": participant,
            "balance": FieldValue.increment(paidShare),
          }, SetOptions(merge: true));

          //participant side (-balance)
          batch.set(participantFriendRef, {
            "phoneNumber": payer,
            "balance": FieldValue.increment(-paidShare),
          }, SetOptions(merge: true));
        }
      }
      //Step 3 commit
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
