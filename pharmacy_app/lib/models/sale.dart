import 'sale_item.dart';

class Sale {
  final int id;
  final String receiptNumber;
  final int soldById;
  final double totalAmount;
  final String createdAt;
  final String paymentMethod;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.receiptNumber,
    required this.soldById,
    required this.totalAmount,
    required this.createdAt,
    required this.paymentMethod,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] ?? 0,
      receiptNumber: json['receipt_number'] ?? '',
      soldById: json['sold_by'] ?? 0,
      totalAmount:
          double.tryParse(json['total_amount'].toString()) ?? 0.0,
      createdAt: json['created_at'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) => SaleItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Intentionally omit:
      // id
      // sold_by
      // total_amount
      // created_at

      'receipt_number': receiptNumber,
      'payment_method': paymentMethod,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}