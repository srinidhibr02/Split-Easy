import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';

class ProfileTab extends StatefulWidget {
  // ignore: use_super_parameters
  const ProfileTab({Key? key}) : super(key: key);

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthServices _authServices = AuthServices();
  final FirestoreServices _firestoreServices = FirestoreServices();

  @override
  Widget build(BuildContext context) {
    final user = _authServices.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("PROFILE SETTING"),
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _firestoreServices.streamUserProfile(user!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("User Data not found"));
          }
          final data = snapshot.data!;
          final name = data["name"] ?? "No Name";
          final avatarUrl = data["avatar"] ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: secondary,
                        backgroundImage:
                            (avatarUrl.isNotEmpty &&
                                avatarUrl.startsWith("http"))
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 12,
                          ),
                          child: Text(
                            "Preferences",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Notification
                        ListTile(
                          leading: const Icon(
                            Icons.notifications,
                            color: primary,
                          ),
                          title: const Text("Notification"),
                          subtitle: const Text(
                            "Customize your notification preferences",
                          ),
                          trailing: Switch(
                            value: false, // bind this to your state
                            onChanged: (val) {
                              // TODO: handle toggle
                            },
                          ),
                        ),

                        // FAQ
                        ListTile(
                          leading: const Icon(
                            Icons.help_outline,
                            color: primary,
                          ),
                          title: const Text("FAQ"),
                          subtitle: const Text("Securely add payment method"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // TODO: Navigate to FAQ screen
                          },
                        ),

                        // Logout
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            "Log Out",
                            style: TextStyle(color: Colors.red),
                          ),
                          subtitle: const Text("Securely log out of Account"),
                          onTap: () async {
                            await _authServices.signOut();
                            Navigator.of(
                              context,
                            ).pushReplacementNamed("/authScreen");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Logged out")),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
