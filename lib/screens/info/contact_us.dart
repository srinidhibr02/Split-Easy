import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/services/auth_services.dart';
import 'package:split_easy/services/firestore_services.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final AuthServices _auth = AuthServices();
  final FirestoreServices _fire = FirestoreServices();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSending = false;
  String? _submitError;
  String? _submitSuccess;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final data = await _fire.fetchUserData(
        _auth.currentUser!.phoneNumber as String,
      );
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _emailController.text = data['email'] ?? '';
      }
    } catch (e) {
      debugPrint("Error loading user details: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    setState(() {
      _submitError = null;
      _submitSuccess = null;
    });

    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSending = true);

    try {
      // TODO: Implement backend logic for sending message

      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _submitSuccess = "Your message has been sent!";
      });
      _messageController.clear();
    } catch (_) {
      setState(() {
        _submitError = "Failed to send. Please try again later.";
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  InputDecoration _modernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: primary),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text(
            "Contact Us",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          "Contact Us",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // App icon or logo
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: primary.withOpacity(0.1),
                          child: ClipOval(
                            child: Image.asset(
                              'images/split_easy.png',
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          "We're here to help!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Have questions, feedback, or facing issues?\nWrite to us below.",
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: _modernInputDecoration(
                            "Your Name",
                            Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your name";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _modernInputDecoration(
                            "Your Email",
                            Icons.email_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your email";
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(value)) {
                              return "Please enter a valid email";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Message
                        TextFormField(
                          controller: _messageController,
                          minLines: 4,
                          maxLines: 8,
                          decoration: _modernInputDecoration(
                            "Your Message",
                            Icons.chat_bubble_outline,
                          ).copyWith(alignLabelWithHint: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please enter your message";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Error or Success
                        if (_submitError != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _submitError!,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_submitSuccess != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _submitSuccess!,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_submitError != null || _submitSuccess != null)
                          const SizedBox(height: 12),

                        // Send Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isSending
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              _isSending ? "Sending..." : "Send Message",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 3,
                            ),
                            onPressed: _isSending ? null : _handleSend,
                          ),
                        ),
                        const SizedBox(height: 8),

                        const Text(
                          'We usually respond within 24 hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
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
