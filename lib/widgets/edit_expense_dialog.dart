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
  required Future<void> Function({
    required String groupId,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  })
  onDeleteExpense,
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
      onDeleteExpense: onDeleteExpense,
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

  final Future<void> Function({
    required String groupId,
    required String expenseId,
    required String expenseTitle,
    required double amount,
    required Map<String, double> paidBy,
    required Map<String, double> participants,
  })
  onDeleteExpense;

  final Stream<Map<String, dynamic>> Function(String) streamGroupById;

  const EditExpenseDialog({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.expense,
    required this.onEditExpense,
    required this.onDeleteExpense,
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
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
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
                  stream: widget.streamGroupById(widget.groupId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleField(),
                          const SizedBox(height: 14),
                          _buildAmountField(),
                          const SizedBox(height: 16),
                          _buildPayersSection(members),
                          const SizedBox(height: 16),
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
            child: const Icon(Icons.edit_note, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Edit Expense",
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
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
          controller: titleController,
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
          controller: amountController,
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
                    child: Icon(
                      Icons.person,
                      color: Colors.green[700],
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedPayers.isEmpty
                          ? "Tap to select who paid"
                          : "${selectedPayers.length} payer(s) selected",
                      style: TextStyle(
                        color: selectedPayers.isEmpty
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
        ),
        if (selectedPayers.isNotEmpty) ...[
          const SizedBox(height: 8),
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
            Icon(Icons.people, size: 18, color: Colors.orange[700]),
            const SizedBox(width: 6),
            const Text(
              "Split Between",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                    child: Icon(
                      Icons.group,
                      color: Colors.orange[700],
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedParticipants.isEmpty
                          ? "Tap to select participants"
                          : "${selectedParticipants.length} participant(s) selected",
                      style: TextStyle(
                        color: selectedParticipants.isEmpty
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
        ),
        if (selectedParticipants.isNotEmpty) ...[
          const SizedBox(height: 8),
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
          Text(
            error,
            style: TextStyle(
              fontSize: 11,
              color: Colors.red[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 50, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "Delete Expense?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "This action cannot be undone. All data related to this expense will be permanently deleted.",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await widget.onDeleteExpense(
        groupId: widget.groupId,
        expenseId: widget.expenseId,
        expenseTitle: widget.expense["title"] ?? "Unknown Expense",
        amount: widget.expense["amount"]?.toDouble() ?? 0.0,
        paidBy: Map<String, double>.from(widget.expense["paidBy"] ?? {}),
        participants: Map<String, double>.from(
          widget.expense["participants"] ?? {},
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Expense deleted successfully!',
                  style: TextStyle(fontSize: 13),
                ),
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar("Failed to delete expense: $e"));
    }
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
      child: Column(
        children: [
          // Main action buttons row
          Row(
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
                  onPressed: _isLoading ? null : _saveExpense,
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "Update",
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _confirmAndDelete,
              icon: Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Colors.red.shade600,
              ),
              label: Text(
                "Delete Expense",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.red.shade300, width: 1.5),
                backgroundColor: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              const Text(
                'Expense updated successfully!',
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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_buildErrorSnackBar("Failed to update expense: $e"));
    }
  }
}
