import 'package:flutter/material.dart';
import 'package:split_easy/constants.dart';

class FriendsBalanceWidget extends StatelessWidget {
  final List<Map<String, dynamic>> friends;

  const FriendsBalanceWidget({super.key, required this.friends});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // 👈 prevents infinite height
        children: [
          // Header Row (Compact)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withAlpha((255 * 0.3).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                "Friends Overview",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withAlpha((255 * 0.25).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${friends.length}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Friends List
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: friends.length > 10 ? 10 : friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final balance = friend['balance'] as double;
                final name = friend['name'] as String;
                final avatar = friend['avatar'] as String?;

                return Container(
                  width: 120,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: balance > 0
                          ? [Colors.green.shade50, Colors.green.shade100]
                          : [Colors.red.shade50, Colors.red.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: balance > 0
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // 👈 added fix
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: balance > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          balance > 0 ? "owes you" : "you owe",
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "₹${balance.abs().toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: balance > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
