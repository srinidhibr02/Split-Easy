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
  _MemberSelectionDialogState createState() => _MemberSelectionDialogState();
}

class _MemberSelectionDialogState extends State<MemberSelectionDialog> {
  late Map<String, double> selectedMembers;
  bool equalSplit = true;
  Map<String, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize with the passed initial selected members
    selectedMembers = Map.from(widget.initialSelected);

    // Initialize controllers for each selected member
    for (var entry in selectedMembers.entries) {
      controllers[entry.key] = TextEditingController(
        text: entry.value.toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateEqualSplit() {
    if (selectedMembers.isEmpty) return;

    double equalAmount = widget.amount / selectedMembers.length;
    setState(() {
      for (var key in selectedMembers.keys) {
        selectedMembers[key] = equalAmount;
        // Update controller text as well
        if (controllers.containsKey(key)) {
          controllers[key]?.text = equalAmount.toStringAsFixed(2);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total contributions
    double totalContributions = selectedMembers.values.fold(
      0,
      (sum, val) => sum + val,
    );
    double difference = widget.amount - totalContributions;

    return AlertDialog(
      title: const Text("Select Members"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Display expense amount
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Expense Amount:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "₹${widget.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Display total and difference for unequal split
            if (!equalSplit && selectedMembers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: difference.abs() < 0.01
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: difference.abs() < 0.01
                        ? Colors.green.shade200
                        : Colors.red.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Total Entered:",
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          "₹${totalContributions.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: difference.abs() < 0.01
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Remaining:",
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          difference >= 0
                              ? "₹${difference.toStringAsFixed(2)}"
                              : "-₹${(-difference).toStringAsFixed(2)}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: difference.abs() < 0.01
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (difference.abs() >= 0.01) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                difference > 0
                                    ? "Add ₹${difference.toStringAsFixed(2)} more to match total"
                                    : "Reduce by ₹${(-difference).toStringAsFixed(2)} to match total",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Perfect! Total matches expense amount",
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            SwitchListTile(
              title: Text(equalSplit ? "Equal Split" : "Custom Split"),
              subtitle: const Text("Distribution method"),
              activeThumbColor: primary,
              value: equalSplit,
              onChanged: (v) {
                setState(() {
                  equalSplit = v;
                  if (equalSplit && selectedMembers.isNotEmpty) {
                    _updateEqualSplit();
                  }
                });
              },
            ),
            const Divider(),
            ...widget.members.map((m) {
              final phone = m["phoneNumber"] as String;
              final name = m["name"] as String;
              final isSelected = selectedMembers.containsKey(phone);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    activeColor: primary,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                        if (equalSplit && isSelected) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${selectedMembers[phone]?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ],
                    ),
                    value: isSelected,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          if (equalSplit) {
                            selectedMembers[phone] = 0.0;
                            _updateEqualSplit();
                          } else {
                            selectedMembers[phone] = 0.0;
                          }
                        } else {
                          selectedMembers.remove(phone);
                          if (equalSplit && selectedMembers.isNotEmpty) {
                            _updateEqualSplit();
                          }
                        }
                      });
                    },
                  ),
                  if (!equalSplit && isSelected) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 56,
                        right: 16,
                        bottom: 12,
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Amount",
                          prefixText: "₹ ",
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        controller: controllers[phone],
                        onChanged: (val) {
                          double amount = double.tryParse(val) ?? 0.0;
                          setState(() {
                            selectedMembers[phone] = amount;
                          });
                        },
                      ),
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: primary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            // Validate before returning
            if (selectedMembers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select at least one member'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Check if total matches amount in custom split mode
            if (!equalSplit) {
              double total = selectedMembers.values.fold(
                0,
                (sum, val) => sum + val,
              );
              if ((total - widget.amount).abs() > 0.01) {
                // Don't allow saving if amounts don't match
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Total must equal ₹${widget.amount.toStringAsFixed(2)}. Currently: ₹${total.toStringAsFixed(2)}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            }

            Navigator.pop(context, selectedMembers);
          },
          child: const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
