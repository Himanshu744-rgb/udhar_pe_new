import 'package:cloud_firestore/cloud_firestore.dart';

class UdhariEntry {
  final String id;
  final String name;
  final String contact;
  final double amount;
  final DateTime date;
  final String shopId;
  final String shopName;

  UdhariEntry({
    required this.id,
    required this.name,
    required this.contact,
    required this.amount,
    required this.date,
    required this.shopId,
    required this.shopName,
  });

  factory UdhariEntry.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    DateTime parseDate() {
      try {
        if (data['date'] is Timestamp) {
          return (data['date'] as Timestamp).toDate();
        } else if (data['date'] is String) {
          return DateTime.parse(data['date']);
        }
        return DateTime.now();
      } catch (e) {
        return DateTime.now();
      }
    }

    return UdhariEntry(
      id: doc.id,
      name: data['name'] ?? '',
      contact: data['contact'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: parseDate(),
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'contact': contact,
    'amount': amount,
    'date': date.toIso8601String(),
    'shopId': shopId,
    'shopName': shopName,
  };
}
