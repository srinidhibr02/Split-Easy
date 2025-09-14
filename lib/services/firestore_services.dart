import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreServices {
  final _fireStore = FirebaseFirestore.instance;

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
}
