import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_easy/constants.dart';
import 'package:split_easy/widgets/member_selection_dialog.dart';

void showAddExpenseDialog(
  BuildContext context, {
  required Map<String, dynamic> group,
  required Function({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  })
  onAddExpense,
  required Stream<Map<String, dynamic>> Function(String) streamGroupById,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AddExpenseDialog(
      group: group,
      onAddExpense: onAddExpense,
      streamGroupById: streamGroupById,
    ),
  );
}

class AddExpenseDialog extends StatefulWidget {
  final Map<String, dynamic> group;
  final Function({
    required String groupId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  })
  onAddExpense;
  final Stream<Map<String, dynamic>> Function(String) streamGroupById;

  const AddExpenseDialog({
    super.key,
    required this.group,
    required this.onAddExpense,
    required this.streamGroupById,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  Map<String, double> _selectedPayers = {};
  Map<String, double> _selectedParticipants = {};
  bool _isLoading = false;
  String? _titleError;
  String? _amountError;
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

    _titleController.addListener(_onTitleChanged);
    _amountController.addListener(_onAmountChanged);
  }

  void _onTitleChanged() {
    if (_titleError != null && _titleController.text.trim().isNotEmpty) {
      setState(() => _titleError = null);
    }
  }

  void _onAmountChanged() {
    if (_amountError != null) {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount != null && amount > 0) {
        setState(() => _amountError = null);
      }
    }
  }

  bool _validateForm() {
    bool isValid = true;

    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = "Title is required");
      isValid = false;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _amountError = "Enter valid amount");
      isValid = false;
    }

    if (_selectedPayers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar("Please select at least one payer"));
      isValid = false;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar("Please select at least one participant"),
      );
      isValid = false;
    }

    // Validate payers sum matches amount
    if (amount != null && _selectedPayers.isNotEmpty) {
      final payersSum = _selectedPayers.values.reduce((a, b) => a + b);
      if ((payersSum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(
            "Payers total (₹${payersSum.toStringAsFixed(2)}) must equal expense amount",
          ),
        );
        isValid = false;
      }
    }

    return isValid;
  }

  SnackBar _buildErrorSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onAddExpense(
        groupId: widget.group["id"],
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        paidBy: _selectedPayers,
        participants: _selectedParticipants,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text("Expense added successfully!"),
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar("Failed to add expense"));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: widget.streamGroupById(widget.group["id"]),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: primary),
                        ),
                      );
                    }

                    final updatedGroup = snapshot.data ?? {};
                    final members =
                        (updatedGroup["members"] as List<dynamic>? ?? [])
                            .map((e) => e as Map<String, dynamic>)
                            .toList();

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleField(),
                          const SizedBox(height: 20),
                          _buildAmountField(),
                          const SizedBox(height: 24),
                          _buildPayersSection(members),
                          const SizedBox(height: 24),
                          _buildParticipantsSection(members),
                        ],
                      ),
                    );
                  },
                ),
              ),

              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add Expense",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Split expenses with your group",
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.title, size: 20, color: primary),
            const SizedBox(width: 8),
            const Text(
              "Expense Title",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: "e.g., Dinner at restaurant",
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _titleError != null
                    ? Colors.red[300]!
                    : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
            ),
            prefixIcon: Icon(Icons.edit_outlined, color: Colors.grey[600]),
          ),
        ),
        if (_titleError != null) _buildErrorText(_titleError!),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.currency_rupee, size: 20, color: primary),
            const SizedBox(width: 8),
            const Text(
              "Amount",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          enabled: !_isLoading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "0.00",
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _amountError != null
                    ? Colors.red[300]!
                    : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2),
            ),
            prefixText: "₹ ",
            prefixStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ),
        if (_amountError != null) _buildErrorText(_amountError!),
      ],
    );
  }

  Widget _buildPayersSection(List<Map<String, dynamic>> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.account_balance_wallet,
              size: 20,
              color: Colors.green[700],
            ),
            const SizedBox(width: 8),
            const Text(
              "Who Paid?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isLoading
              ? null
              : () async {
                  // Get the current amount when dialog opens
                  final currentAmount =
                      double.tryParse(_amountController.text.trim()) ?? 0;

                  if (currentAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      _buildErrorSnackBar("Please enter an amount first"),
                    );
                    return;
                  }

                  final result = await showDialog(
                    context: context,
                    builder: (_) => MemberSelectionDialog(
                      members: members,
                      amount: currentAmount,
                      initialSelected: _selectedPayers,
                    ),
                  );
                  if (result != null) {
                    setState(
                      () => _selectedPayers = Map<String, double>.from(result),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPayers.isEmpty
                        ? "Tap to select who paid"
                        : "${_selectedPayers.length} payer(s) selected",
                    style: TextStyle(
                      color: _selectedPayers.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.green[700],
                ),
              ],
            ),
          ),
        ),
        if (_selectedPayers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedMembers(_selectedPayers, members, Colors.green),
        ],
      ],
    );
  }

  Widget _buildParticipantsSection(List<Map<String, dynamic>> members) {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people, size: 20, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text(
              "Split Between",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _isLoading
              ? null
              : () async {
                  final result = await showDialog(
                    context: context,
                    builder: (_) => MemberSelectionDialog(
                      members: members,
                      amount: amount,
                      initialSelected: _selectedParticipants,
                    ),
                  );
                  if (result != null) {
                    setState(
                      () => _selectedParticipants = Map<String, double>.from(
                        result,
                      ),
                    );
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.group, color: Colors.orange[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedParticipants.isEmpty
                        ? "Tap to select participants"
                        : "${_selectedParticipants.length} participant(s) selected",
                    style: TextStyle(
                      color: _selectedParticipants.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.orange[700],
                ),
              ],
            ),
          ),
        ),
        if (_selectedParticipants.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedMembers(_selectedParticipants, members, Colors.orange),
        ],
      ],
    );
  }

  Widget _buildSelectedMembers(
    Map<String, double> selected,
    List<Map<String, dynamic>> members,
    MaterialColor color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected (${selected.length})",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color[900],
            ),
          ),
          const SizedBox(height: 8),
          ...selected.entries.map((entry) {
            final member = members.firstWhere(
              (m) => m["phoneNumber"] == entry.key,
              orElse: () => {"name": "Unknown"},
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color[100],
                    child: Text(
                      member["name"][0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color[900],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member["name"],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "₹${entry.value.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
          const SizedBox(width: 6),
          Text(
            error,
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Add Expense",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
