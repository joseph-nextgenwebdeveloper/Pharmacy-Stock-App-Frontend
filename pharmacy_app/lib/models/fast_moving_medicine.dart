class FastMovingMedicine {
  final String medicine;
  final String sku;
  final int quantityDispensed;

  const FastMovingMedicine({
    required this.medicine,
    required this.sku,
    required this.quantityDispensed,
  });

  factory FastMovingMedicine.fromJson(
    Map<String, dynamic> json,
  ) {
    return FastMovingMedicine(
      medicine: json['medicine'] ?? '',
      sku: json['sku'] ?? '',
      quantityDispensed:
          json['quantity_dispensed'] ?? 0,
    );
  }
}