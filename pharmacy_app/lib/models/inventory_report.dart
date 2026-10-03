class InventoryReport {
  final String medicine;
  final String sku;
  final int quantity;
  final int reorderLevel;
  final String status;

  const InventoryReport({
    required this.medicine,
    required this.sku,
    required this.quantity,
    required this.reorderLevel,
    required this.status,
  });

  factory InventoryReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return InventoryReport(
      medicine: json['medicine'] ?? '',
      sku: json['sku'] ?? '',
      quantity: json['quantity'] ?? 0,
      reorderLevel: json['reorder_level'] ?? 0,
      status: json['status'] ?? '',
    );
  }
}