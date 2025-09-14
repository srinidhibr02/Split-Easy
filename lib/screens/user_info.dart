import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/auth_services.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedAvatar;

  final _authService = AuthServices();

  final List<String> avatar = [
    "https://cdn-icons-png.flaticon.com/512/4140/4140037.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140047.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140051.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140040.png",
    "https://cdn-icons-png.flaticon.com/512/6997/6997662.png",
    "https://cdn-icons-png.flaticon.com/512/6997/6997668.png",
    "https://cdn-icons-png.flaticon.com/512/6997/6997675.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140038.png",
    "https://cdn-icons-png.flaticon.com/512/4140/4140041.png",
  ];

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _selectedAvatar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Enter your name & Select an avatar"),
        ),
      );
      return;
    }
    try {
      await _authService.saveUserInfo(
        name: _nameController.text,
        avatar: _selectedAvatar!,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully.")),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update Profile.")),
      );
    }
    Navigator.pushReplacementNamed(context, "/homeScreen");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete your profile"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Enter your Name", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Your Name",
                ),
              ),
              const SizedBox(height: 20),
              const Text("Choose an avatar", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: avatar.length,
                  itemBuilder: (context, index) {
                    final avatarurl = avatar[index];
                    final isSelected = _selectedAvatar == avatarurl;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatar = avatarurl;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? primary : Colors.grey.shade300,
                            width: 3,
                          ),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          backgroundImage: NetworkImage(avatarurl),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text("Continue"),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
