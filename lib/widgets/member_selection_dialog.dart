import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';

class MemberSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final Map<String, double> initialSelected;
  final double amount;

  const MemberSelectionDialog({
    super.key,
    required this.members,
    required this.amount,
    required this.initialSelected,
  });

  @override
  State<MemberSelectionDialog> createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<MemberSelectionDialog> {
  late Map<String, double> selectedMembers;
  bool equalSplit = true;
  bool selectAll = false;
  final Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    selectedMembers = Map.from(widget.initialSelected);
    for (var entry in selectedMembers.entries) {
      controllers[entry.key] = TextEditingController(
        text: entry.value.toStringAsFixed(2),
      );
    }
    if (selectedMembers.length == widget.members.length &&
        widget.members.isNotEmpty) {
      selectAll = true;
    }
    if (equalSplit && selectedMembers.isNotEmpty) {
      _updateEqualSplit();
    }
  }

  @override
  void dispose() {
    for (var c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void toggleSelectAll(bool? checked) {
    setState(() {
      selectAll = checked ?? false;
      if (selectAll) {
        for (var m in widget.members) {
          final phone = m["phoneNumber"] as String;
          selectedMembers[phone] = 0.0;
          controllers.putIfAbsent(
            phone,
            () => TextEditingController(text: "0.00"),
          );
        }
        _updateEqualSplit();
      } else {
        selectedMembers.clear();
        for (var c in controllers.values) {
          c.dispose();
        }
        controllers.clear();
      }
    });
  }

  void _updateEqualSplit() {
    if (selectedMembers.isEmpty) return;
    final equalAmount = widget.amount / selectedMembers.length;
    final keys = selectedMembers.keys.toList();
    setState(() {
      for (var key in keys) {
        selectedMembers[key] = equalAmount;
        controllers.putIfAbsent(
          key,
          () => TextEditingController(text: equalAmount.toStringAsFixed(2)),
        );
        controllers[key]?.text = equalAmount.toStringAsFixed(2);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = selectedMembers.values.fold<double>(0.0, (a, b) => a + b);
    final difference = widget.amount - total;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(25),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Select Members",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Expense Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Total Expense",
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    "₹${widget.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Split Mode Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!equalSplit) {
                          setState(() {
                            equalSplit = true;
                            if (selectedMembers.isEmpty &&
                                widget.members.isNotEmpty) {
                              for (var m in widget.members) {
                                final phone = m['phoneNumber'] as String;
                                selectedMembers[phone] = 0.0;
                                controllers.putIfAbsent(
                                  phone,
                                  () => TextEditingController(text: "0.00"),
                                );
                              }
                              selectAll = true;
                            }
                            _updateEqualSplit();
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: equalSplit ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          "Equal Split",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: equalSplit
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (equalSplit) {
                          setState(() {
                            equalSplit = false;
                            for (var key in selectedMembers.keys) {
                              controllers.putIfAbsent(
                                key,
                                () => TextEditingController(
                                  text: selectedMembers[key]!.toStringAsFixed(
                                    2,
                                  ),
                                ),
                              );
                            }
                            selectAll = false;
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !equalSplit ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          "Custom Split",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !equalSplit
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Summary for Custom Split
            if (!equalSplit && selectedMembers.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: difference.abs() < 0.01
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: difference.abs() < 0.01
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow(
                      "Total Entered",
                      "₹${total.toStringAsFixed(2)}",
                      primary,
                    ),
                    const SizedBox(height: 3),
                    _infoRow(
                      "Remaining",
                      difference >= 0
                          ? "₹${difference.toStringAsFixed(2)}"
                          : "-₹${(-difference).toStringAsFixed(2)}",
                      difference.abs() < 0.01
                          ? Colors.green.shade800
                          : Colors.red.shade700,
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: difference.abs() < 0.01
                          ? _messageBox(
                              "Perfect! Total matches expense amount",
                              icon: Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              background: Colors.green.shade100,
                            )
                          : _messageBox(
                              "Add ₹${difference.toStringAsFixed(2)} more to match total",
                              icon: Icons.error_outline,
                              color: Colors.red.shade700,
                              background: Colors.red.shade100,
                            ),
                    ),
                  ],
                ),
              ),

            // Show "Select All" only in Equal Split mode
            if (equalSplit)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: CheckboxListTile(
                  value: selectAll,
                  onChanged: toggleSelectAll,
                  title: const Text(
                    "Select All Members",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.green,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  dense: true,
                ),
              ),

            // Members List
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  itemCount: widget.members.length,
                  itemBuilder: (context, index) {
                    final m = widget.members[index];
                    final phone = m["phoneNumber"];
                    final name = m["name"];
                    final isSelected = selectedMembers.containsKey(phone);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary.withOpacity(0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? primary.withOpacity(0.3)
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedMembers[phone] = 0.0;
                                  controllers.putIfAbsent(
                                    phone,
                                    () => TextEditingController(text: "0.00"),
                                  );
                                  if (equalSplit) _updateEqualSplit();
                                } else {
                                  selectedMembers.remove(phone);
                                  controllers.remove(phone)?.dispose();
                                  if (equalSplit &&
                                      selectedMembers.isNotEmpty) {
                                    _updateEqualSplit();
                                  }
                                }
                              });
                            },
                            activeColor: primary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            dense: true,
                            title: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: primary.withOpacity(0.1),
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (equalSplit && isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "₹${selectedMembers[phone]?.toStringAsFixed(2) ?? '0.00'}",
                                      style: const TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!equalSplit && isSelected)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(52, 0, 12, 10),
                              child: TextField(
                                controller: controllers[phone],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  labelText: "Amount",
                                  labelStyle: const TextStyle(fontSize: 13),
                                  prefixText: "₹ ",
                                  prefixStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  isDense: true,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (val) {
                                  setState(() {
                                    selectedMembers[phone] =
                                        double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Buttons
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _onSavePressed,
                    child: const Text(
                      "Save",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
    );
  }

  void _onSavePressed() {
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!equalSplit) {
      double total = selectedMembers.values.fold(0.0, (a, b) => a + b);
      if ((total - widget.amount).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Total must equal ₹${widget.amount.toStringAsFixed(2)} (Current: ₹${total.toStringAsFixed(2)})',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    Navigator.pop(context, selectedMembers);
  }

  Widget _infoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _messageBox(
    String message, {
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
