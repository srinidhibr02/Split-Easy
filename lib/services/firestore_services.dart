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

    final batch = _fireStore.batch();

    // 1️⃣ Add member to group's members array
    batch.update(groupDoc, {
      "members": FieldValue.arrayUnion([newMemberInfo]),
    });

    // 2️⃣ Add groupId to new member's groups array
    batch.update(newMemberDoc, {
      "groups": FieldValue.arrayUnion([groupId]),
    });

    // 3️⃣ Add new member as a friend to all existing group members (bidirectional)
    final members = List<Map<String, dynamic>>.from(groupData["members"] ?? []);

    for (final member in members) {
      final memberPhone = member["phoneNumber"];
      final memberDoc = _fireStore.collection("users").doc(memberPhone);

      // Add newMember to existing member’s friends
      batch.set(
        memberDoc.collection("friends").doc(newMemberPhoneNumber),
        newMemberInfo,
      );

      // Add existing member to newMember’s friends
      batch.set(newMemberDoc.collection("friends").doc(memberPhone), {
        "phoneNumber": member["phoneNumber"],
        "name": member["name"],
        "avatar": member["avatar"],
      });
    }

    // Commit all updates
    await batch.commit();

    print(
      "${newMemberData["name"]} added to group '${groupData["groupName"]}' and bidirectional friendships created",
    );
  }

  //Stream of friends for the current User
  Stream<List<Map<String, dynamic>>> getFriendsStream() {
    final phone = currentPhoneNumber;

    if (phone == null) {
      throw Exception("No user logged in");
    }

    final friendsCollection = _fireStore
        .collection("users")
        .doc(phone)
        .collection("friends");

    return friendsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          "id": doc.id, // doc.id is the friend’s phone number
          ...data, // spread Firestore document data
        };
      }).toList();
    });
  }

  //adds expence to a group and updates balances for each member
  Future<void> addExpense({
    required String groupId,
    required String title,
    required double amount,
    required List<String> paidBy,
    required List<String> participants,
    required Map<String, double> splits,
    required Map<String, double> contributions,
    required String splitType,
  }) async {
    final batch = _fireStore.batch();

    // 1️⃣ Add expense to group
    final expenseRef = _fireStore
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .doc();

    batch.set(expenseRef, {
      "title": title,
      "amount": amount,
      "paidBy": paidBy,
      "participants": participants,
      "splits": splits,
      "contributions": contributions,
      "splitType": splitType,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // 2️⃣ Update balances for each participant
    for (final user in participants) {
      final net = (contributions[user] ?? 0) - (splits[user] ?? 0);

      for (final other in participants) {
        if (user == other) continue;

        // update user -> other balance
        final userFriendRef = _fireStore
            .collection("users")
            .doc(user)
            .collection("friends")
            .doc(other);

        batch.set(userFriendRef, {
          "balance": FieldValue.increment(net),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // update other -> user balance (inverse)
        final otherFriendRef = _fireStore
            .collection("users")
            .doc(other)
            .collection("friends")
            .doc(user);

        batch.set(otherFriendRef, {
          "balance": FieldValue.increment(-net),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  Future<void> updateExpense({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required List<String> paidBy,
    required List<String> participants,
    required Map<String, double> splits,
    required Map<String, double> contributions,
    required String splitType,
  }) async {
    final expenseRef = _fireStore
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .doc(expenseId);

    await expenseRef.update({
      "title": title,
      "amount": amount,
      "paidBy": paidBy,
      "participants": participants,
      "splits": splits,
      "contributions": contributions,
      "splitType": splitType,
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // Optionally, you can also update balances here if needed
  }
}
