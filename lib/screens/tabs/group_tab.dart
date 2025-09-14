import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/screens/create_group_screen.dart';
import 'package:split_easy/screens/group_details_screen.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';

class GroupTab extends StatefulWidget {
  // ignore: use_super_parameters
  GroupTab({Key? key}) : super(key: key);

  @override
  State<GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends State<GroupTab> {
  final FirestoreServices _firestoreServices = FirestoreServices();
  final AuthServices _authServices = AuthServices();

  IconData getPurposeIcon(String? label) {
    final purpose = purposes.firstWhere(
      (p) => p["label"] == label,
      orElse: () => {"icon": Icons.group}, // default fallback
    );
    return purpose["icon"] as IconData;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity, // takes full available width
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateGroupScreen()),
                  );
                  if (result == true) {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.group_add_outlined),
                label: const Text(
                  "Create a group +",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    width: 1.2,
                    color: primary,
                  ), // visible border
                  foregroundColor: primary,
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreServices.streamUserGroups(
                  _authServices.currentUser!,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        "No Groups Found",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }
                  final groups = snapshot.data!;

                  return ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Card(
                        // ignore: deprecated_member_use
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 10),

                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primary,
                            child: Icon(
                              getPurposeIcon(group["purpose"]),
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            group["name"] ?? "Unnamed",
                            style: const TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            group["purpose"] ?? "",
                            style: TextStyle(color: primary),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GroupDetailsScreen(group: group),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
