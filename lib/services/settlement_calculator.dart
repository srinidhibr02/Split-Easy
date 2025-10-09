import 'package:split_easy/dataModels/dataModels.dart';

class SettlementCalculator {
  static List<Settlement> calculateSettlements(Map<String, dynamic> group) {
    final members =
        (group["members"] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    List<Map<String, dynamic>> debtors = [];
    List<Map<String, dynamic>> creditors = [];

    for (var member in members) {
      final balance = (member["balance"] ?? 0.0).toDouble();
      final memberData = {
        "phoneNumber": member["phoneNumber"],
        "name": member["name"],
        "balance": balance.abs(),
      };
      if (balance < -0.01) {
        debtors.add(memberData);
      } else if (balance > 0.01) {
        creditors.add(memberData);
      }
    }

    debtors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );
    creditors.sort(
      (a, b) => (b["balance"] as double).compareTo(a["balance"] as double),
    );

    List<Settlement> settlements = [];
    int i = 0, j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final debtAmount = debtor["balance"] as double;
      final creditAmount = creditor["balance"] as double;
      final settleAmount = debtAmount < creditAmount
          ? debtAmount
          : creditAmount;

      settlements.add(
        Settlement(
          fromPhone: debtor["phoneNumber"],
          fromName: debtor["name"],
          toPhone: creditor["phoneNumber"],
          toName: creditor["name"],
          amount: settleAmount,
        ),
      );

      debtor["balance"] = debtAmount - settleAmount;
      creditor["balance"] = creditAmount - settleAmount;

      if (debtor["balance"] < 0.01) i++;
      if (creditor["balance"] < 0.01) j++;
    }
    return settlements;
  }

  static List<Settlement> getMySettlements(
    Map<String, dynamic> group,
    String currentUserPhone,
  ) {
    final allSettlements = calculateSettlements(group);

    return allSettlements
        .where(
          (s) =>
              s.fromPhone == currentUserPhone || s.toPhone == currentUserPhone,
        )
        .toList();
  }
}
