import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_easy/constants.dart';
import 'member_selection_dialog.dart';

void showEditExpenseDialog(
  BuildContext context, {
  required String groupId,
  required String expenseId,
  required Map<String, dynamic> expense,
  required Function({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
    required Map<String, double> oldPaidBy,
    required Map<String, double> oldParticipants,
  })
  onEditExpense,
  required Stream<Map<String, dynamic>> Function(String) streamGroupById,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => EditExpenseDialog(
      groupId: groupId,
      expenseId: expenseId,
      expense: expense,
      onEditExpense: onEditExpense,
      streamGroupById: streamGroupById,
    ),
  );
}

class EditExpenseDialog extends StatefulWidget {
  final String groupId;
  final String expenseId;
  final Map<String, dynamic> expense;
  final Function({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
    required Map<String, double> oldPaidBy,
    required Map<String, double> oldParticipants,
  })
  onEditExpense;
  final Stream<Map<String, dynamic>> Function(String) streamGroupById;

  const EditExpenseDialog({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.expense,
    required this.onEditExpense,
    required this.streamGroupById,
  });

  @override
  State<EditExpenseDialog> createState() => _EditExpenseDialogState();
}

class _EditExpenseDialogState extends State<EditExpenseDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController titleController;
  late TextEditingController amountController;

  late Map<String, double> selectedPayers;
  late Map<String, double> selectedParticipants;

  late Map<String, double> oldPaidBy;
  late Map<String, double> oldParticipants;

  double lastAmount = 0;
  bool _isLoading = false;
  String? _titleError;
  String? _amountError;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(
      text: widget.expense["title"] ?? "",
    );
    amountController = TextEditingController(
      text: widget.expense["amount"]?.toString() ?? "",
    );

    oldPaidBy = Map<String, double>.from(widget.expense["paidBy"] ?? {});
    oldParticipants = Map<String, double>.from(
      widget.expense["participants"] ?? {},
    );
    selectedPayers = Map<String, double>.from(oldPaidBy);
    selectedParticipants = Map<String, double>.from(oldParticipants);
    lastAmount = widget.expense["amount"]?.toDouble() ?? 0;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();

    titleController.addListener(_onTitleChanged);
    amountController.addListener(_onAmountChanged);
  }

  void _onTitleChanged() {
    if (_titleError != null && titleController.text.trim().isNotEmpty) {
      setState(() => _titleError = null);
    }
  }

  void _onAmountChanged() {
    if (_amountError != null) {
      final amount = double.tryParse(amountController.text.trim());
      if (amount != null && amount > 0) {
        setState(() => _amountError = null);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void recalculateShares(double newAmount) {
    if (newAmount <= 0 || (newAmount - lastAmount).abs() < 0.01) return;

    if (selectedPayers.isNotEmpty) {
      double oldTotal = selectedPayers.values.fold(0, (a, b) => a + b);
      if (oldTotal > 0) {
        setState(() {
          selectedPayers = selectedPayers.map((phone, val) {
            double proportion = val / oldTotal;
            double newVal = (newAmount * proportion * 100).round() / 100;
            return MapEntry(phone, newVal);
          });
        });
      }
    }

    if (selectedParticipants.isNotEmpty) {
      double oldTotal = selectedParticipants.values.fold(0, (a, b) => a + b);
      if (oldTotal > 0) {
        setState(() {
          selectedParticipants = selectedParticipants.map((phone, val) {
            double proportion = val / oldTotal;
            double newVal = (newAmount * proportion * 100).round() / 100;
            return MapEntry(phone, newVal);
          });
        });
      }
    }

    lastAmount = newAmount;
  }

  bool _validateForm() {
    bool isValid = true;

    if (titleController.text.trim().isEmpty) {
      setState(() => _titleError = "Title is required");
      isValid = false;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _amountError = "Enter valid amount");
      isValid = false;
    }

    if (selectedPayers.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar("Please select at least one payer"));
      isValid = false;
    }

    if (selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildErrorSnackBar("Please select at least one participant"),
      );
      isValid = false;
    }

    // Validate totals match amount
    if (amount != null && selectedPayers.isNotEmpty) {
      final payersSum = selectedPayers.values.reduce((a, b) => a + b);
      if ((payersSum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(
            "Payers total (₹${payersSum.toStringAsFixed(2)}) must equal expense amount",
          ),
        );
        isValid = false;
      }
    }

    if (amount != null && selectedParticipants.isNotEmpty) {
      final participantsSum = selectedParticipants.values.reduce(
        (a, b) => a + b,
      );
      if ((participantsSum - amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildErrorSnackBar(
            "Participants total (₹${participantsSum.toStringAsFixed(2)}) must equal expense amount",
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
                  stream: widget.streamGroupById(widget.groupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: CircularProgressIndicator(color: primary),
                        ),
                      );
                    }

                    final groupData = snapshot.data ?? {};
                    final members =
                        (groupData["members"] as List<dynamic>? ?? [])
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
            child: const Icon(Icons.edit_note, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Edit Expense",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Update expense details",
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
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
          controller: titleController,
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
          controller: amountController,
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
          onChanged: (v) {
            double amt = double.tryParse(v) ?? 0;
            if ((amt - lastAmount).abs() > 0.01) {
              recalculateShares(amt);
            }
          },
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
        Semantics(
          button: true,
          label:
              'Who Paid, ${selectedPayers.isEmpty ? "none selected" : "${selectedPayers.length} members selected"}',
          child: InkWell(
            onTap: _isLoading
                ? null
                : () async {
                    final currentAmount =
                        double.tryParse(amountController.text.trim()) ?? 0;

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
                        initialSelected: selectedPayers,
                      ),
                    );
                    if (result != null) {
                      setState(
                        () => selectedPayers = Map<String, double>.from(result),
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
                    child: Icon(
                      Icons.person,
                      color: Colors.green[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedPayers.isEmpty
                          ? "Tap to select who paid"
                          : "${selectedPayers.length} payer(s) selected",
                      style: TextStyle(
                        color: selectedPayers.isEmpty
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
        ),
        if (selectedPayers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedMembers(selectedPayers, members, Colors.green),
        ],
      ],
    );
  }

  Widget _buildParticipantsSection(List<Map<String, dynamic>> members) {
    final amount = double.tryParse(amountController.text.trim()) ?? 0;

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
        Semantics(
          button: true,
          label:
              'Split Between, ${selectedParticipants.isEmpty ? "none selected" : "${selectedParticipants.length} members selected"}',
          child: InkWell(
            onTap: _isLoading
                ? null
                : () async {
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildErrorSnackBar("Please enter an amount first"),
                      );
                      return;
                    }

                    final result = await showDialog(
                      context: context,
                      builder: (_) => MemberSelectionDialog(
                        members: members,
                        amount: amount,
                        initialSelected: selectedParticipants,
                      ),
                    );
                    if (result != null) {
                      setState(
                        () => selectedParticipants = Map<String, double>.from(
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
                    child: Icon(
                      Icons.group,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedParticipants.isEmpty
                          ? "Tap to select participants"
                          : "${selectedParticipants.length} participant(s) selected",
                      style: TextStyle(
                        color: selectedParticipants.isEmpty
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
        ),
        if (selectedParticipants.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSelectedMembers(selectedParticipants, members, Colors.orange),
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
              onPressed: _isLoading ? null : _saveExpense,
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
                          Icons.check_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Update Expense",
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

  Future<void> _saveExpense() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      await widget.onEditExpense(
        groupId: widget.groupId,
        expenseId: widget.expenseId,
        title: titleController.text.trim(),
        amount: double.parse(amountController.text.trim()),
        paidBy: selectedPayers,
        participants: selectedParticipants,
        oldPaidBy: oldPaidBy,
        oldParticipants: oldParticipants,
      );

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Expense updated successfully!'),
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
      ).showSnackBar(_buildErrorSnackBar("Failed to update expense: $e"));
    }
  }
}
