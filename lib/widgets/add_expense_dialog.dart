import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _payersError;
  String? _participantsError;
  String? _sumError;
  String? _amountRequiredError;
  String? _submitError;
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
        setState(() {
          _amountError = null;
          _amountRequiredError = null;
        });
      }
    }
  }

  void _clearValidationErrors() {
    setState(() {
      _payersError = null;
      _participantsError = null;
      _sumError = null;
      _submitError = null;
    });
  }

  bool _validateForm() {
    bool isValid = true;
    _clearValidationErrors();

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
      setState(() => _payersError = "Please select at least one payer");
      isValid = false;
    }

    if (_selectedParticipants.isEmpty) {
      setState(
        () => _participantsError = "Please select at least one participant",
      );
      isValid = false;
    }

    // Validate payers sum matches amount
    if (amount != null && _selectedPayers.isNotEmpty) {
      final payersSum = _selectedPayers.values.reduce((a, b) => a + b);
      if ((payersSum - amount).abs() > 0.01) {
        setState(
          () => _sumError =
              "Payers total (₹${payersSum.toStringAsFixed(2)}) must equal expense amount",
        );
        isValid = false;
      }
    }

    return isValid;
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
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text(
                "Expense added successfully!",
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError = "Failed to add expense";
      });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleField(),
                          const SizedBox(height: 14),
                          _buildAmountField(),
                          const SizedBox(height: 16),
                          _buildPayersSection(members),
                          if (_payersError != null)
                            _buildErrorText(_payersError!),
                          if (_amountRequiredError != null)
                            _buildErrorText(_amountRequiredError!),
                          if (_sumError != null) _buildErrorText(_sumError!),
                          const SizedBox(height: 16),
                          _buildParticipantsSection(members),
                          if (_participantsError != null)
                            _buildErrorText(_participantsError!),
                          if (_submitError != null) ...[
                            const SizedBox(height: 8),
                            _buildErrorText(_submitError!),
                          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Add Expense",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
            Icon(Icons.title, size: 18, color: primary),
            const SizedBox(width: 6),
            const Text(
              "Expense Title",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _titleController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            hintText: "e.g., Dinner at restaurant",
            hintStyle: const TextStyle(fontSize: 14),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _titleError != null
                    ? Colors.red[300]!
                    : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
            ),
            prefixIcon: Icon(
              Icons.edit_outlined,
              color: Colors.grey[600],
              size: 20,
            ),
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
            Icon(Icons.currency_rupee, size: 18, color: primary),
            const SizedBox(width: 6),
            const Text(
              "Amount",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          enabled: !_isLoading,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "0.00",
            hintStyle: const TextStyle(fontSize: 18),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: _amountError != null
                    ? Colors.red[300]!
                    : Colors.grey[200]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primary, width: 2),
            ),
            prefixText: "₹ ",
            prefixStyle: TextStyle(
              fontSize: 18,
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
              size: 18,
              color: Colors.green[700],
            ),
            const SizedBox(width: 6),
            const Text(
              "Who Paid?",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isLoading
              ? null
              : () async {
                  final currentAmount =
                      double.tryParse(_amountController.text.trim()) ?? 0;

                  if (currentAmount <= 0) {
                    setState(
                      () =>
                          _amountRequiredError = "Please enter an amount first",
                    );
                    return;
                  }

                  // Clear the amount required error if amount is valid
                  if (_amountRequiredError != null) {
                    setState(() => _amountRequiredError = null);
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
                    setState(() {
                      _selectedPayers = Map<String, double>.from(result);
                      // Clear payers error when selection is made
                      _payersError = null;
                    });
                  }
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.person, color: Colors.green[700], size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedPayers.isEmpty
                        ? "Tap to select who paid"
                        : "${_selectedPayers.length} payer(s) selected",
                    style: TextStyle(
                      color: _selectedPayers.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.green[700],
                ),
              ],
            ),
          ),
        ),
        if (_selectedPayers.isNotEmpty) ...[
          const SizedBox(height: 8),
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
            Icon(Icons.people, size: 18, color: Colors.orange[700]),
            const SizedBox(width: 6),
            const Text(
              "Split Between",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    setState(() {
                      _selectedParticipants = Map<String, double>.from(result);
                      // Clear participants error when selection is made
                      _participantsError = null;
                    });
                  }
                },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange[200]!, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.group, color: Colors.orange[700], size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedParticipants.isEmpty
                        ? "Tap to select participants"
                        : "${_selectedParticipants.length} participant(s) selected",
                    style: TextStyle(
                      color: _selectedParticipants.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.orange[700],
                ),
              ],
            ),
          ),
        ),
        if (_selectedParticipants.isNotEmpty) ...[
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Selected (${selected.length})",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: color[900],
            ),
          ),
          const SizedBox(height: 6),
          ...selected.entries.map((entry) {
            final member = members.firstWhere(
              (m) => m["phoneNumber"] == entry.key,
              orElse: () => {"name": "Unknown"},
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color[100],
                    child: Text(
                      member["name"][0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color[900],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      member["name"],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "₹${entry.value.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color[900],
                        fontSize: 12,
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
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 13, color: Colors.red[700]),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
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
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                disabledBackgroundColor: primary.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
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
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          "Add Expense",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
