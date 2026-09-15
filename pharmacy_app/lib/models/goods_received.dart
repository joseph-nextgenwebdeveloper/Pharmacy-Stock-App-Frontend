import 'goods_received_item.dart';
class GoodsReceived {
  final int id;
  final int supplier;
  final String invoiceNumber;
  final String receivedDate;
  final int receivedBy;
  final String notes;
  final List<GoodsReceivedItem> items;

  const GoodsReceived({
    required this.id,
    required this.supplier,
    required this.invoiceNumber,
    required this.receivedDate,
    required this.receivedBy,
    required this.notes,
    required this.items,
  });

  factory GoodsReceived.fromJson(Map<String, dynamic> json) {
    return GoodsReceived(
      id: json['id'] ?? 0,
      supplier: json['supplier'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      receivedDate: json['received_date'] ?? '',
      receivedBy: json['received_by'] ?? 0,
      notes: json['notes'] ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) => GoodsReceivedItem.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplier': supplier,
      'invoice_number': invoiceNumber,
      'received_date': receivedDate,
      'received_by': receivedBy,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}