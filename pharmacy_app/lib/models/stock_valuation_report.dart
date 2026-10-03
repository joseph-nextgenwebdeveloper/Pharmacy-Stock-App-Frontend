class StockValuationReport {
  final String medicine;
  final String sku;
  final int quantity;
  final double stockValue;

  const StockValuationReport({
    required this.medicine,
    required this.sku,
    required this.quantity,
    required this.stockValue,
  });

  factory StockValuationReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return StockValuationReport(
      medicine: json['medicine'] ?? '',
      sku: json['sku'] ?? '',
      quantity: json['quantity'] ?? 0,
      stockValue:
          double.tryParse(
            json['stock_value'].toString(),
          ) ??
          0.0,
    );
  }
}