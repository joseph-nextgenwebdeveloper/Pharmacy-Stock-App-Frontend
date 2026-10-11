import 'medicine.dart';

class StockMovement {
  final int id;
  final int medicineId;
  final String medicineName;
  final int batchId;
  final String batchNumber;
  final int quantity;
  final String movementType;
  final int? performedById;
  final String performedByName;
  final String performedByRole;
  final String? performedByAvatar;
  final String note;
  final String movementDate;
  final String date;

  /// RECEIVED / DISPENSED / DAMAGED / EXPIRED / COUNT_DISCREPANCY ...
  final String reason;
  final String reasonLabel;

  /// Delivery (GRN-12) or receipt number this movement belongs to.
  final String reference;

  /// The batch balance before / after this movement (null on old records).
  final int? quantityBefore;
  final int? quantityAfter;

  const StockMovement({
    required this.id,
    required this.medicineId,
    this.medicineName = '',
    required this.batchId,
    this.batchNumber = '',
    required this.quantity,
    required this.movementType,
    this.performedById,
    this.performedByName = '',
    this.performedByRole = '',
    this.performedByAvatar,
    this.note = '',
    required this.movementDate,
    required this.date,
    this.reason = '',
    this.reasonLabel = '',
    this.reference = '',
    this.quantityBefore,
    this.quantityAfter,
  });

  factory StockMovement.fromJson(
    Map<String, dynamic> json,
  ) {
    return StockMovement(
      id: json['id'] ?? 0,
      medicineId: json['medicine'] ?? 0,
      medicineName: json['medicine_name'] ?? '',
      batchId: json['batch'] ?? 0,
      batchNumber: json['batch_number'] ?? '',
      quantity: json['quantity'] ?? 0,
      movementType: json['movement_type'] ?? '',
      performedById: json['performed_by'],
      performedByName: json['performed_by_name'] ?? '',
      performedByRole: json['performed_by_role'] ?? '',
      performedByAvatar:
          Medicine.resolveImageUrl(json['performed_by_avatar'] as String?),
      note: json['note'] ?? '',
      movementDate: json['movement_date'] ?? '',
      date: json['date'] ?? '',
      reason: json['reason'] ?? '',
      reasonLabel: json['reason_label'] ?? '',
      reference: json['reference'] ?? '',
      quantityBefore: json['quantity_before'] as int?,
      quantityAfter: json['quantity_after'] as int?,
    );
  }

  bool get isIn => movementType.toUpperCase() == 'IN';

  /// "Received", "Dispensed", "Damaged"... (falls back to the direction).
  String get label {
    if (reasonLabel.isNotEmpty) return reasonLabel;
    return isIn ? 'Received' : 'Dispensed';
  }

  /// The moment this happened, in the phone's local time zone.
  DateTime? get when {
    final raw = movementDate.isNotEmpty ? movementDate : date;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Calendar day (local) this movement belongs to.
  DateTime? get day {
    final w = when;
    return w == null ? null : DateTime(w.year, w.month, w.day);
  }

  /// "Jane Otieno" or "Unknown user" for very old records.
  String get who => performedByName.isNotEmpty ? performedByName : 'Unknown user';
}
