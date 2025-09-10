import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/screens/create_group_screen.dart';

class GroupTab extends StatelessWidget {
  // ignore: use_super_parameters
  GroupTab({Key? key}) : super(key: key);

  final List<String> groups = [
    "Sigandoor Trip",
    "Maharastra Jyotirlinga",
    "Bitti Porty",
  ];

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
                onPressed: () {
                  Navigator.pushReplacementNamed(context, "/createGroupScreen");
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
              child: groups.isEmpty
                  ? const Center(
                      child: Text(
                        "No Groups Found",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.group),
                            ),
                            title: Text(groups[index]),
                            onTap: () {
                              //TODO Navigate to group details Screen
                            },
                          ),
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
