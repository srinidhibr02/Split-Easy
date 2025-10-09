import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void showAddMemberDialog(
  BuildContext context, {
  required String groupId,
  required Function(String phoneNumber, {String? customName}) onAddMember,
}) {
  showDialog(
    context: context,
    builder: (_) => AddMemberDialog(groupId: groupId, onAddMember: onAddMember),
  );
}

class AddMemberDialog extends StatefulWidget {
  final String groupId;
  final Function(String phoneNumber, {String? customName}) onAddMember;

  const AddMemberDialog({
    super.key,
    required this.groupId,
    required this.onAddMember,
  });

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingUser = false;
  bool _userExists = true;
  bool _showNameField = false;
  String? _errorText;
  String? _nameErrorText;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
    _phoneController.addListener(_onPhoneNumberChanged);
  }

  void _onPhoneNumberChanged() {
    if (_phoneController.text.length == 10) {
      _checkUserExists();
    } else {
      setState(() {
        _userExists = true;
        _showNameField = false;
        if (_errorText != null) _errorText = null;
      });
    }
  }

  Future<void> _checkUserExists() async {
    setState(() => _isCheckingUser = true);

    try {
      final phoneNumber = '+91${_phoneController.text.trim()}';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(phoneNumber)
          .get();

      setState(() {
        _userExists = userDoc.exists;
        _showNameField = !userDoc.exists;
        _isCheckingUser = false;
      });
    } catch (e) {
      setState(() => _isCheckingUser = false);
    }
  }

  bool _validateInputs() {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() => _errorText = "Phone number is required");
      return false;
    }

    if (phone.length != 10) {
      setState(() => _errorText = "Please enter 10 digits");
      return false;
    }

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      setState(() => _errorText = "Invalid Indian phone number");
      return false;
    }

    if (_showNameField) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(
          () => _nameErrorText = "Name is required for unregistered users",
        );
        return false;
      }
      if (name.length < 2) {
        setState(() => _nameErrorText = "Name must be at least 2 characters");
        return false;
      }
    }

    return true;
  }

  Future<void> _handleAddMember() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final phoneNumber = '+91${_phoneController.text.trim()}';
      final customName = _showNameField ? _nameController.text.trim() : null;

      await widget.onAddMember(phoneNumber, customName: customName);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorText = null;
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _userExists
                      ? "Member added successfully!"
                      : "Unregistered user added successfully!",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Extract the error message
      final errorMessage = e.toString();

      setState(() {
        _isLoading = false;
        _errorText = errorMessage;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Member",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Enter phone number to invite",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone Number Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _errorText != null
                              ? Colors.red.shade300
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  "🇮🇳",
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "+91",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              autofocus: true,
                              enabled: !_isLoading,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                              decoration: InputDecoration(
                                hintText: "00000 00000",
                                hintStyle: TextStyle(
                                  color: Colors.grey[400],
                                  letterSpacing: 1.2,
                                ),
                                counterText: "",
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: _isCheckingUser
                                    ? Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: primary,
                                          ),
                                        ),
                                      )
                                    : _phoneController.text.length == 10
                                    ? Icon(
                                        Icons.check_circle,
                                        color: Colors.green[600],
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Character Count & User Status
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${_phoneController.text.length}/10 digits",
                            style: TextStyle(
                              fontSize: 12,
                              color: _phoneController.text.length == 10
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              fontWeight: _phoneController.text.length == 10
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (_phoneController.text.length == 10 &&
                              !_isCheckingUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _userExists
                                    ? Colors.green[50]
                                    : Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _userExists
                                      ? Colors.green[200]!
                                      : Colors.orange[200]!,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _userExists
                                        ? Icons.verified_user
                                        : Icons.person_outline,
                                    size: 14,
                                    color: _userExists
                                        ? Colors.green[700]
                                        : Colors.orange[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _userExists
                                        ? "Registered"
                                        : "Not Registered",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _userExists
                                          ? Colors.green[700]
                                          : Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Error Message
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 18,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Name Field for Unregistered Users
                    if (_showNameField) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "User not registered. Please provide a name.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        enabled: !_isLoading,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: "Member Name",
                          hintText: "Enter member's name",
                          prefixIcon: Icon(
                            Icons.person,
                            color: Colors.grey[600],
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _nameErrorText != null
                                  ? Colors.red[300]!
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primary, width: 2),
                          ),
                        ),
                        onChanged: (value) {
                          if (_nameErrorText != null && value.length >= 2) {
                            setState(() => _nameErrorText = null);
                          }
                        },
                      ),
                      if (_nameErrorText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 14,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _nameErrorText!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 12),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _userExists
                                  ? "Member will be notified via SMS"
                                  : "User can register later to see expenses",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleAddMember,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.person_add,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _showNameField
                                        ? "Add Anyway"
                                        : "Add Member",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
