// Data model for a settlement transaction

class Settlement {
  final String fromPhone;
  final String fromName;
  final String toPhone;
  final String toName;
  final double amount;

  Settlement({
    required this.fromPhone,
    required this.fromName,
    required this.toPhone,
    required this.toName,
    required this.amount,
  });
}

class FriendBalance {
  final String name;
  final String avatar;
  final double balance;

  FriendBalance({
    required this.name,
    required this.avatar,
    required this.balance,
  });
}
