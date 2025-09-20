import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreServices {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;

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
    required User user,
    required String name,
    required String purpose,
  }) async {
    if (user == null) return;
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);
    await userDoc.update({
      "groups": FieldValue.arrayUnion([
        {
          "name": name,
          "purpose": purpose,
          "createdAt": DateTime.now(),
          "members": [user.phoneNumber],
        },
      ]),
    });
  }

  Stream<List<Map<String, dynamic>>> streamUserGroups(User user) {
    if (user == null) return const Stream.empty();

    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);

    return userDoc.snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final groups = snapshot.data()?["groups"] as List<dynamic>?;
      return groups != null
          ? groups.map((e) => Map<String, dynamic>.from(e)).toList()
          : [];
    });
  }

  Future<void> addMemberToGroup({
    required String userId, // Owner phone number
    required String groupName,
    required String newMemberPhoneNumber,
  }) async {
    if (newMemberPhoneNumber.isEmpty) {
      throw Exception("Invalid member phone number");
    }

    final userDoc = _fireStore.collection("users").doc(userId);
    final newMemberDoc = _fireStore
        .collection("users")
        .doc(newMemberPhoneNumber);

    await _fireStore.runTransaction((transaction) async {
      // --- Step 1: Read owner & new member docs ---
      final userSnapshot = await transaction.get(userDoc);
      if (!userSnapshot.exists) throw Exception("Owner not found");

      final newMemberSnapshot = await transaction.get(newMemberDoc);

      final userGroups = List<Map<String, dynamic>>.from(
        userSnapshot.data()?["groups"] ?? [],
      );
      final groupIndex = userGroups.indexWhere((g) => g["name"] == groupName);

      if (groupIndex == -1) throw Exception("Group not found");

      // --- Step 2: Work with full group object ---
      final groupData = Map<String, dynamic>.from(userGroups[groupIndex]);

      // Update members list only
      final updatedMembers = <String>{
        ...List<String>.from(groupData["members"] ?? []),
        newMemberPhoneNumber,
      };
      groupData["members"] = updatedMembers.toList();

      // Replace owner’s copy with updated groupData
      userGroups[groupIndex] = groupData;

      // --- Step 3: If new member exists, add groupData ---
      List<Map<String, dynamic>>? newMemberGroups;
      if (newMemberSnapshot.exists) {
        newMemberGroups = List<Map<String, dynamic>>.from(
          newMemberSnapshot.data()?["groups"] ?? [],
        );
        if (!newMemberGroups.any((g) => g["name"] == groupName)) {
          newMemberGroups.add(groupData);
        }
      }

      // --- Step 4: Prepare updates for all existing members ---
      final otherMemberDocs = <DocumentReference>[];
      final otherMemberGroupsList = <List<Map<String, dynamic>>>[];

      for (final memberPhone in updatedMembers) {
        if (memberPhone == userId || memberPhone == newMemberPhoneNumber)
          continue;

        final memberDoc = _fireStore.collection("users").doc(memberPhone);
        final memberSnapshot = await transaction.get(memberDoc);
        if (!memberSnapshot.exists) continue;

        final memberGroups = List<Map<String, dynamic>>.from(
          memberSnapshot.data()?["groups"] ?? [],
        );

        final idx = memberGroups.indexWhere((g) => g["name"] == groupName);
        if (idx != -1) {
          // Replace whole group object so purpose, createdAt, etc. are in sync
          memberGroups[idx] = groupData;
        }
        otherMemberDocs.add(memberDoc);
        otherMemberGroupsList.add(memberGroups);
      }

      // --- Step 5: Perform writes ---
      transaction.update(userDoc, {"groups": userGroups});
      if (newMemberGroups != null) {
        transaction.update(newMemberDoc, {"groups": newMemberGroups});
      }
      for (int i = 0; i < otherMemberDocs.length; i++) {
        transaction.update(otherMemberDocs[i], {
          "groups": otherMemberGroupsList[i],
        });
      }
    });
  }

  Future<String> getUserNameByPhone(String phone) async {
    final doc = await _fireStore.collection("users").doc(phone).get();

    if (doc.exists) {
      final data = doc.data();
      return data!["name"] ?? phone;
    } else {
      return phone;
    }
  }
}
