class SlowMovingMedicine {
  final String medicine;
  final String sku;
  final int quantityDispensed;

  const SlowMovingMedicine({
    required this.medicine,
    required this.sku,
    required this.quantityDispensed,
  });

  factory SlowMovingMedicine.fromJson(
    Map<String, dynamic> json,
  ) {
    return SlowMovingMedicine(
      medicine: json['medicine'] ?? '',
      sku: json['sku'] ?? '',
      quantityDispensed:
          json['quantity_dispensed'] ?? 0,
    );
  }
}