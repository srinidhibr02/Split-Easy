import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_easy/services/activity_service.dart';
import 'package:split_easy/services/friend_balance_service.dart';

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

  Future<void> createGroup({
    required String groupName,
    required String purpose,
  }) async {
    final userDoc = _firestore.collection("users").doc(currentUserPhone);

    // Get user data
    final userSnapshot = await userDoc.get();
    final userData = userSnapshot.exists ? userSnapshot.data()! : {};
    final userName = userData["name"] ?? "Unknown";
    final userAvatar = userData["avatar"] ?? "default_avatar_url";

    // Define initial members list
    final members = [
      {"phoneNumber": currentUserPhone, "name": userName, "avatar": userAvatar},
    ];

    // Extract only phone numbers for fast querying
    final memberPhones = members
        .map((m) => m["phoneNumber"] as String)
        .toList();

    // Create a new group in the global 'groups' collection
    final newGroupDoc = await _firestore.collection("groups").add({
      "groupName": groupName,
      "purpose": purpose,
      "createdAt": FieldValue.serverTimestamp(),
      "owner": {
        "phoneNumber": currentUserPhone,
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
    ActivityService().createGroupActivity(
      groupId: groupId,
      groupName: groupName,
      creatorPhone: currentUserPhone,
      creatorName: userName,
    );
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
      throw Exception("Group not found");
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
      // Create a basic document for unregistered user
      await newMemberDoc.set({
        "phoneNumber": newMemberPhoneNumber,
        "name": customName ?? "Unknown",
        "avatar": "default_avatar",
        "groups": [],
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
      "balance": 0.0, // Initialize balance for new member
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
    // CRITICAL FIX: Use SetOptions(merge: true) to preserve existing data
    final members = List<Map<String, dynamic>>.from(groupData["members"] ?? []);

    for (final member in members) {
      final memberPhone = member["phoneNumber"];
      final memberDoc = _firestore.collection("users").doc(memberPhone);

      // Add new member to existing member's friends (MERGE to preserve balance)
      batch.set(
        memberDoc.collection("friends").doc(newMemberPhoneNumber),
        {
          "phoneNumber": newMemberPhoneNumber,
          "name": newMemberInfo["name"],
          "avatar": newMemberInfo["avatar"],
          // Note: Don't set balance here - it will be calculated later
          // If balance field exists, merge will preserve it
          "lastUpdated": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // ✅ CRITICAL: Merge instead of overwrite
      );

      // Add existing member to new member's friends (MERGE to preserve balance)
      batch.set(
        newMemberDoc.collection("friends").doc(memberPhone),
        {
          "phoneNumber": member["phoneNumber"],
          "name": member["name"],
          "avatar": member["avatar"] ?? "",
          // Note: Don't set balance here - it will be calculated later
          "lastUpdated": FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true), // ✅ CRITICAL: Merge instead of overwrite
      );
    }

    // Commit all updates
    await batch.commit();

    print("✅ Member added to group successfully");

    // Member added activity logging
    await ActivityService().memberAddedActivity(
      groupId: groupId,
      groupName: groupData["groupName"],
      addedByPhone: addedByMemberInfo["phoneNumber"],
      addedByName: addedByMemberInfo["name"],
      newMemberPhone: newMemberPhoneNumber,
      newMemberName: newMemberData["name"],
    );

    print("✅ Activity logged");

    // OPTIONAL: Recalculate friend balances for the new member
    // This ensures all friend balances are accurate after adding the member
    try {
      print("🔄 Recalculating friend balances for new member...");

      // Get all groups that both new member and existing members are in
      final newMemberGroupsSnapshot = await _firestore
          .collection('groups')
          .where('memberPhones', arrayContains: newMemberPhoneNumber)
          .get();

      final newMemberGroups = newMemberGroupsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // For each existing member in this group, recalculate balance with new member
      for (final member in members) {
        final memberPhone = member["phoneNumber"];

        // Calculate balance between new member and this existing member
        final balance = await FriendsBalanceService().calculateFriendBalance(
          userPhone: newMemberPhoneNumber,
          friendPhone: memberPhone,
          groups: newMemberGroups,
        );

        // Update the balance (this will merge with existing friend data)
        await FriendsBalanceService().updateFriendBalances(
          fromPhone: newMemberPhoneNumber,
          toPhone: memberPhone,
          amount: balance,
        );
      }

      print("✅ Friend balances recalculated");
    } catch (e) {
      print("⚠️ Warning: Could not recalculate friend balances: $e");
      // Don't throw - member was added successfully, this is just a bonus
    }
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
      return [];
    }
  }
}
