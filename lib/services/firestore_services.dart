import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreServices {
  final _fireStore = FirebaseFirestore.instance;

  Future<void> createUserInFireStore(User? user) async {
    if (user == null) return;
    final userDoc = _fireStore.collection("users").doc(user.uid);
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      await userDoc.set({
        "uid": user.uid,
        "phoneNumber": user.phoneNumber,
        "createdAt": FieldValue.serverTimestamp(),
        "isProfileCompleted": false, // you can use this later
      });
    }
  }
}
