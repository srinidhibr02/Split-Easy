import 'package:cloud_firestore/cloud_firestore.dart';

class StreamOperations {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Stream<Map<String, dynamic>> streamGroupById(String groupId) {
    return firestore.collection("groups").doc(groupId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return {};
      final data = snapshot.data()!;
      data["id"] = snapshot.id;
      return data;
    });
  }
}
