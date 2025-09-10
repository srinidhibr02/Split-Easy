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
    required String name,
    required String purpose,
  }) async {
    await _fireStore.collection("groups").add({
      "name": name,
      "purpose": purpose,
      "createdAt": DateTime.now(),
    });
  }
}
