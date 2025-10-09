import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/friend_balance_service.dart';
import 'package:split_easy/services/settlement_service.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserPhone => _auth.currentUser?.phoneNumber ?? "";

  // Stream groups for the current user based on subcollection
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

  /// Stream a single group by ID
  Stream<Map<String, dynamic>> streamGroupById(String groupId) {
    return _firestore.collection("groups").doc(groupId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return {};
      final data = snapshot.data()!;
      data["id"] = snapshot.id;
      return data;
    });
  }

  Stream<int> streamExpenseCount(String groupId) {
    return _firestore
        .collection("groups")
        .doc(groupId)
        .collection("expenses")
        .snapshots()
        .map((snapshot) => snapshot.size);
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

  double getMyBalance(Map<String, dynamic> group) {
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
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {"id": doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Get user and group names in one batch read
  Future<Map<String, String>> getUserAndGroupNames(
    String userPhone,
    String groupId,
  ) async {
    final batch = await Future.wait([
      _firestore.collection('users').doc(userPhone).get(),
      _firestore.collection('groups').doc(groupId).get(),
    ]);

    return {
      'userName': batch[0].data()?['name'] ?? 'Someone',
      'groupName': batch[1].data()?['groupName'] ?? 'Group',
    };
  }

  Future<void> createGroupWithActivity({
    required String groupName,
    required List<Map<String, dynamic>> members,
  }) async {
    final currentUserPhone = _auth.currentUser?.phoneNumber ?? "";

    final userDoc = await _firestore
        .collection('users')
        .doc(currentUserPhone)
        .get();
    final userName = userDoc.data()?['name'] ?? 'You';

    try {
      final groupRef = await _firestore.collection('groups').add({
        'groupName': groupName,
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserPhone,
      });

      await ActivityService().createGroupActivity(
        groupId: groupRef.id,
        groupName: groupName,
        creatorPhone: currentUserPhone,
        creatorName: userName,
      );

      print('Group created successfully');
    } catch (e) {
      print('Error: $e');
      rethrow;
    }
  }

  Future<void> addMemberToGroup({
    required String groupId,
    required String newMemberPhoneNumber,
    required String addedByPhoneNumber,
    String? customName,
  }) async {
    final groupDoc = _firestore.collection("groups").doc(groupId);
    final newMemberDoc = _firestore
        .collection("users")
        .doc(newMemberPhoneNumber);
    final addedByMemberDoc = _firestore
        .collection("users")
        .doc(addedByPhoneNumber);

    // Get group data
    final groupSnapshot = await groupDoc.get();
    if (!groupSnapshot.exists) {
      return;
    }
    final groupData = groupSnapshot.data()!;

    // Check if the new member is already in the group
    final memberPhones = List<String>.from(groupData["memberPhones"] ?? []);
    if (memberPhones.contains(newMemberPhoneNumber)) {
      throw Exception("Member already in group");
    }

    // Get or create new member document
    final newMemberSnapshot = await newMemberDoc.get();
    if (!newMemberSnapshot.exists) {
      // Create a basic document for unregistered user before batching update
      await newMemberDoc.set({
        "phoneNumber": newMemberPhoneNumber,
        "name": customName ?? "Unknown",
        "avatar": "default_avatar",
        "groups": [], // Initialize groups field to avoid update errors
      }, SetOptions(merge: true));
    }

    // Refresh new member snapshot after creation
    final newMemberData = (await newMemberDoc.get()).data()!;

    // Get addedBy member data
    final addedByMemberSnapshot = await addedByMemberDoc.get();
    final addedByMemberData = addedByMemberSnapshot.exists
        ? addedByMemberSnapshot.data()!
        : {"name": "Unknown", "avatar": "default_avatar_url"};

    final addedByMemberInfo = {
      "phoneNumber": addedByPhoneNumber,
      "name": addedByMemberData["name"],
    };

    final newMemberInfo = {
      "phoneNumber": newMemberPhoneNumber,
      "name": newMemberData["name"],
      "avatar": newMemberData["avatar"] ?? "",
    };

    final batch = _firestore.batch();

    // 1️⃣ Add member to group's members array
    batch.update(groupDoc, {
      "members": FieldValue.arrayUnion([newMemberInfo]),
      "memberPhones": FieldValue.arrayUnion([newMemberPhoneNumber]),
    });

    // 2️⃣ Add groupId to new member's groups array
    batch.update(newMemberDoc, {
      "groups": FieldValue.arrayUnion([groupId]),
    });

    // 3️⃣ Add new member as a friend to all existing group members (bidirectional)
    final members = List<Map<String, dynamic>>.from(groupData["members"] ?? []);

    for (final member in members) {
      final memberPhone = member["phoneNumber"];
      final memberDoc = _firestore.collection("users").doc(memberPhone);

      batch.set(
        memberDoc.collection("friends").doc(newMemberPhoneNumber),
        newMemberInfo,
      );

      batch.set(newMemberDoc.collection("friends").doc(memberPhone), {
        "phoneNumber": member["phoneNumber"],
        "name": member["name"],
        "avatar": member["avatar"],
      });
    }

    // Commit all updates
    await batch.commit();

    // Member added activity logging
    ActivityService().memberAddedActivity(
      groupId: groupId,
      groupName: groupData["groupName"],
      addedByPhone: addedByMemberInfo["phoneNumber"],
      addedByName: addedByMemberInfo["name"],
      newMemberPhone: newMemberPhoneNumber,
      newMemberName: newMemberData["name"],
    );
  }

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String memberPhoneNumber,
  }) async {
    final groupDoc = _firestore.collection('groups').doc(groupId);
    final memberDoc = _firestore.collection('users').doc(memberPhoneNumber);

    // Load group data
    final groupSnapshot = await groupDoc.get();
    if (!groupSnapshot.exists) return;
    final groupData = groupSnapshot.data()!;
    final members = List<Map<String, dynamic>>.from(groupData['members'] ?? []);
    final memberPhones = List<String>.from(groupData['memberPhones'] ?? []);

    // Ensure the member is in the group
    if (!memberPhones.contains(memberPhoneNumber)) return;

    // 0️⃣ Check for pending settlements
    final fromQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('fromPhone', isEqualTo: memberPhoneNumber)
        .limit(1)
        .get();
    final toQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('toPhone', isEqualTo: memberPhoneNumber)
        .limit(1)
        .get();
    if (fromQuery.docs.isNotEmpty || toQuery.docs.isNotEmpty) {
      throw Exception('pending_settlements');
    }

    // Begin batch
    final batch = _firestore.batch();

    // 1️⃣ Remove from group's members and memberPhones
    batch.update(groupDoc, {
      'members': FieldValue.arrayRemove([
        members.firstWhere((m) => m['phoneNumber'] == memberPhoneNumber),
      ]),
      'memberPhones': FieldValue.arrayRemove([memberPhoneNumber]),
    });

    // 2️⃣ Remove groupId from the user's groups array
    batch.update(memberDoc, {
      'groups': FieldValue.arrayRemove([groupId]),
    });

    // 3️⃣ Remove friendships in both directions
    for (final m in members) {
      final otherPhone = m['phoneNumber'] as String;
      if (otherPhone == memberPhoneNumber) continue;
      final otherFriendsDoc = _firestore
          .collection('users')
          .doc(otherPhone)
          .collection('friends')
          .doc(memberPhoneNumber);
      batch.delete(otherFriendsDoc);
      final thisFriendsDoc = memberDoc.collection('friends').doc(otherPhone);
      batch.delete(thisFriendsDoc);
    }

    // 4️⃣ Remove any suggestedSettlements involving this member
    final settlementsQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('fromPhone', isEqualTo: memberPhoneNumber)
        .get();
    for (final doc in settlementsQuery.docs) {
      batch.delete(doc.reference);
    }
    final reverseQuery = await groupDoc
        .collection('suggestedSettlements')
        .where('toPhone', isEqualTo: memberPhoneNumber)
        .get();
    for (final doc in reverseQuery.docs) {
      batch.delete(doc.reference);
    }

    // Commit all operations
    await batch.commit();

    final removedByPhone = _auth.currentUser?.phoneNumber ?? "Unknown";
    final removerDoc = await _firestore
        .collection('users')
        .doc(removedByPhone)
        .get();
    final removedByName = removerDoc.data()?['name'] ?? 'Unknown';
    final removedMemberName = members.firstWhere(
      (m) => m['phoneNumber'] == memberPhoneNumber,
    )['name'];

    // Activity Service
    ActivityService().memberRemovedActivity(
      groupId: groupId,
      groupName: groupData["groupName"],
      removedByPhone: removedByPhone,
      removedByName: removedByName,
      removedMemberPhone: memberPhoneNumber,
      removedMemberName: removedMemberName,
    );
  }

  // Cache for member groups to reduce reads
  final Map<String, List<Map<String, dynamic>>> _memberGroupsCache = {};

  Future<List<Map<String, dynamic>>> getMemberGroups(String memberPhone) async {
    // Check cache first
    if (_memberGroupsCache.containsKey(memberPhone)) {
      return _memberGroupsCache[memberPhone]!;
    }

    try {
      final allGroupsSnapshot = await _firestore.collection('groups').get();

      final memberGroups = <Map<String, dynamic>>[];
      for (var doc in allGroupsSnapshot.docs) {
        final data = doc.data();
        final members = List<dynamic>.from(data['members'] ?? []);

        if (members.any((m) => m['phoneNumber'] == memberPhone)) {
          memberGroups.add({'id': doc.id, ...data});
        }
      }

      // Cache for 30 seconds
      _memberGroupsCache[memberPhone] = memberGroups;
      Future.delayed(const Duration(seconds: 30), () {
        _memberGroupsCache.remove(memberPhone);
      });

      return memberGroups;
    } catch (e) {
      print('Error getting member groups: $e');
      return [];
    }
  }
}
