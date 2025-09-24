import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/firestore_services.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController nameController = TextEditingController();
  final FirestoreServices _firestoreServices = FirestoreServices();

  bool isLoading = false;
  String? selectedPurpose;

  final List<Map<String, dynamic>> purposes = [
    {"label": "Trip", "icon": Icons.airplanemode_active},
    {"label": "Group", "icon": Icons.group},
    {"label": "Family", "icon": Icons.family_restroom},
    {"label": "Couple", "icon": Icons.favorite},
    {"label": "Others", "icon": Icons.widgets},
  ];

  Future<void> _createGroup() async {
    final String groupName = nameController.text.trim();
    if (groupName.isEmpty || selectedPurpose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please Fill all the fields")),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });

    try {
      await _firestoreServices.createGroup(
        groupName: groupName,
        purpose: selectedPurpose!,
      );
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Group Created Successfully!")),
      );
      // ignore: use_build_context_synchronously
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundImage: AssetImage("images/split_easy.png"),
                  backgroundColor: Colors.transparent,
                ),
                const SizedBox(width: 18),
                const Text(
                  "Create a group",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: primary),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Group Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "Select Purpose",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 12,
                children: purposes.map((p) {
                  final isSelected = selectedPurpose == p["label"];
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p["icon"], size: 18),
                        const SizedBox(width: 6),
                        Text(p["label"]),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        selectedPurpose = p["label"];
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                  );
                }).toList(),
              ),

              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Create Group",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
