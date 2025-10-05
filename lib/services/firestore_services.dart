import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/activity_service.dart';

class FirestoreServices {
  final FirebaseFirestore _fireStore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();

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

    final docSnapshot = await userDoc.get();

    if (docSnapshot.exists) {
      // ✅ Update only specific fields
      await userDoc.update({
        "name": userName,
        "avatar": avatar,
        "isProfileCompleted": true,
      });
    } else {
      // ✅ Create new document
      await userDoc.set({
        "name": userName,
        "avatar": avatar,
        "isProfileCompleted": true,
      });
    }
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

    // Define initial members list
    final members = [
      {
        "phoneNumber": currentPhoneNumber,
        "name": userName,
        "avatar": userAvatar,
      },
    ];

    // Extract only phone numbers for fast querying
    final memberPhones = members
        .map((m) => m["phoneNumber"] as String)
        .toList();

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
      "members": members,
      "memberPhones": memberPhones, // <-- added for easier queries
    });

    final groupId = newGroupDoc.id;

    // Add groupId to the owner's 'groups' array
    await userDoc.update({
      "groups": FieldValue.arrayUnion([groupId]),
    });
    _activityService.createGroupActivity(
      groupId: groupId,
      groupName: groupName,
      creatorPhone: currentPhoneNumber as String,
      creatorName: userName,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamGroupById(
    String groupId,
  ) {
    return _fireStore.collection("groups").doc(groupId).snapshots();
  }

  Stream<List<Map<String, dynamic>>> streamUserGroups(User user) {
    final userDoc = _fireStore.collection("users").doc(user.phoneNumber);

    return userDoc.snapshots().asyncExpand((snapshot) {
      if (!snapshot.exists) return Stream.value([]);

      final groupIds = List<String>.from(snapshot.data()?["groups"] ?? []);

      if (groupIds.isEmpty) return Stream.value([]);

      // Listen to changes in all group documents
      return _fireStore
          .collection("groups")
          .where(FieldPath.documentId, whereIn: groupIds)
          .snapshots()
          .map((query) {
            return query.docs
                .map((doc) => {"id": doc.id, ...doc.data()})
                .toList();
          });
    });
  }

  Future<void> addMemberToGroup({
    required String groupId,
    required String newMemberPhoneNumber,
    required String addedByPhoneNumber,
  }) async {
    final groupDoc = _fireStore.collection("groups").doc(groupId);
    final newMemberDoc = _fireStore
        .collection("users")
        .doc(newMemberPhoneNumber);

    final addedByMemberDoc = _fireStore
        .collection("users")
        .doc(addedByPhoneNumber);

    // Get group data
    final groupSnapshot = await groupDoc.get();
    if (!groupSnapshot.exists) {
      return;
    }
    final groupData = groupSnapshot.data()!;

    // Get new member data
    final newMemberSnapshot = await newMemberDoc.get();
    final addedByMemberSnapshot = await addedByMemberDoc.get();
    final addedByMemberData = addedByMemberSnapshot.exists
        ? addedByMemberSnapshot.data()!
        : {"name": "Unknown", "avatar": "default_avatar_url"};

    final newMemberData = newMemberSnapshot.exists
        ? newMemberSnapshot.data()!
        : {"phoneNumber": "Not_Found", "name": "Unknown"};

    final addedByMemberInfo = {
      "phoneNumber": addedByPhoneNumber,
      "name": addedByMemberData["name"],
    };

    final newMemberInfo = {
      "phoneNumber": newMemberPhoneNumber,
      "name": newMemberData["name"],
      "avatar": newMemberData["avatar"],
    };

    final batch = _fireStore.batch();

    // 1️⃣ Add member to group's members array
    batch.update(groupDoc, {
      "members": FieldValue.arrayUnion([newMemberInfo]),
      "memberPhones": FieldValue.arrayUnion([
        newMemberPhoneNumber,
      ]), // <-- update memberPhones
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

    // Member added activity
    _activityService.memberAddedActivity(
      groupId: groupId,
      groupName: groupData["groupName"],
      addedByPhone: addedByMemberInfo["phoneNumber"],
      addedByName: addedByMemberInfo["name"],
      newMemberPhone: newMemberPhoneNumber,
      newMemberName: newMemberData["name"],
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
}
