import 'package:uuid/uuid.dart';

class Transaction {
  String id;
  String title;
  double amount;
  DateTime date;

  Transaction({required this.id, required this.title, required this.amount, required this.date});

  static String generateId() {
    return Uuid().v4();
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "title": title, "amount": amount, "date": date.toIso8601String()};
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
    );
  }
}
