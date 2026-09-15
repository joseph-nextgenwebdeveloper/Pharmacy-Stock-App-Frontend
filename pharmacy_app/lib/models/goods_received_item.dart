class GoodsReceivedItem {
  final int id;
  final int medicine;
  final String batchNumber;
  final String manufactureDate;
  final String expiryDate;
  final int quantity;
  final double buyingPrice;

  const GoodsReceivedItem({
    required this.id,
    required this.medicine,
    required this.batchNumber,
    required this.manufactureDate,
    required this.expiryDate,
    required this.quantity,
    required this.buyingPrice,
  });

  factory GoodsReceivedItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return GoodsReceivedItem(
      id: json['id'] ?? 0,
      medicine: json['medicine'] ?? 0,
      batchNumber: json['batch_number'] ?? '',
      manufactureDate: json['manufacture_date'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      quantity: json['quantity'] ?? 0,
      buyingPrice: double.tryParse(
            json['buying_price'].toString(),
          ) ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'medicine': medicine,
      'batch_number': batchNumber,
      'manufacture_date': manufactureDate,
      'expiry_date': expiryDate,
      'quantity': quantity,
      'buying_price': buyingPrice,
    };
  }
}