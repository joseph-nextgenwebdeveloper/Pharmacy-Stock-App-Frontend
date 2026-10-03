class ExpiredMedicineReport {
  final String medicine;
  final String sku;
  final String batchNumber;
  final String expiryDate;
  final int quantity;

  const ExpiredMedicineReport({
    required this.medicine,
    required this.sku,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
  });

  factory ExpiredMedicineReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return ExpiredMedicineReport(
      medicine: json['medicine'] ?? '',
      sku: json['sku'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      quantity: json['quantity'] ?? 0,
    );
  }
}