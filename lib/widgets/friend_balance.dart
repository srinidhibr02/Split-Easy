import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';

// Widget to display friends balances
class FriendsBalanceWidget extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const FriendsBalanceWidget({super.key, required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withAlpha((255 * 0.5).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "Friends Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primary.withAlpha((255 * 0.5).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${friends.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: friends.length > 10 ? 10 : friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];
              final balance = friend['balance'] as double;
              final name = friend['name'] as String;
              final avatar = friend['avatar'] as String?;

              return Container(
                width: 150,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: balance > 0
                        ? [Colors.green.shade50, Colors.green.shade100]
                        : [Colors.red.shade50, Colors.red.shade100],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: balance > 0
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          balance > 0 ? "owes you" : "you owe",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${balance.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: balance > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
