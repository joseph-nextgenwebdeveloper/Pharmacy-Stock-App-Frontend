class StockMovement {
  final int id;
  final int medicineId;
  final int batchId;
  final int quantity;
  final String movementType;
  final int? performedById;
  final String movementDate;
  final String date;

  const StockMovement({
    required this.id,
    required this.medicineId,
    required this.batchId,
    required this.quantity,
    required this.movementType,
    this.performedById,
    required this.movementDate,
    required this.date,
  });

  factory StockMovement.fromJson(
    Map<String, dynamic> json,
  ) {
    return StockMovement(
      id: json['id'] ?? 0,
      medicineId: json['medicine'] ?? 0,
      batchId: json['batch'] ?? 0,
      quantity: json['quantity'] ?? 0,
      movementType: json['movement_type'] ?? '',
      performedById: json['performed_by'],
      movementDate: json['movement_date'] ?? '',
      date: json['date'] ?? '',
    );
  }
}