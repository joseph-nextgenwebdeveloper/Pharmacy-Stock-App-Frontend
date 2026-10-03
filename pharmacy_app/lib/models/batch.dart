class Batch {
  final int id;
  final int medicineId;
  final String batchNumber;
  final String manufactureDate;
  final String expiryDate;
  final int quantity;
  final double buyingPrice;
  final String receivedDate;

  const Batch({
    required this.id,
    required this.medicineId,
    required this.batchNumber,
    required this.manufactureDate,
    required this.expiryDate,
    required this.quantity,
    required this.buyingPrice,
    required this.receivedDate,
  });

  factory Batch.fromJson(
    Map<String, dynamic> json,
  ) {
    return Batch(
      id: json['id'] ?? 0,
      medicineId: json['medicine'] ?? 0,
      batchNumber: json['batch_number'] ?? '',
      manufactureDate: json['manufacture_date'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      quantity: json['quantity'] ?? 0,
      buyingPrice: double.tryParse(
            json['buying_price']?.toString() ?? '0',
          ) ??
          0.0,
      receivedDate: json['received_date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine': medicineId,
      'batch_number': batchNumber,
      'manufacture_date': manufactureDate,
      'expiry_date': expiryDate,
      'quantity': quantity,
      'buying_price': buyingPrice,
    };
  }
}