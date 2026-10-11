/// One received lot of ONE medicine.
class Batch {
  final int id;
  final int medicineId;
  final String medicineName;
  final String medicineSku;
  final String batchNumber;
  final String manufactureDate;
  final String expiryDate;

  /// Available quantity (drops as stock is sold / dispensed).
  final int quantity;

  /// Quantity originally received.
  final int originalQuantity;
  final double buyingPrice;
  final double sellingPrice;
  final int? supplierId;
  final String supplierName;
  final String receivedDate;
  final String _serverStatus;

  const Batch({
    required this.id,
    required this.medicineId,
    this.medicineName = '',
    this.medicineSku = '',
    required this.batchNumber,
    this.manufactureDate = '',
    required this.expiryDate,
    required this.quantity,
    this.originalQuantity = 0,
    required this.buyingPrice,
    this.sellingPrice = 0,
    this.supplierId,
    this.supplierName = '',
    this.receivedDate = '',
    String status = '',
  }) : _serverStatus = status;

  factory Batch.fromJson(
    Map<String, dynamic> json,
  ) {
    return Batch(
      id: json['id'] ?? 0,
      medicineId: json['medicine'] ?? 0,
      medicineName: json['medicine_name'] ?? '',
      medicineSku: json['medicine_sku'] ?? '',
      batchNumber: json['batch_number'] ?? '',
      manufactureDate: json['manufacture_date'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      quantity: json['quantity'] ?? 0,
      originalQuantity: json['original_quantity'] ?? 0,
      buyingPrice: double.tryParse(json['buying_price']?.toString() ?? '0') ?? 0.0,
      sellingPrice:
          double.tryParse(json['selling_price']?.toString() ?? '0') ?? 0.0,
      supplierId: json['supplier'] as int?,
      supplierName: json['supplier_name'] ?? '',
      receivedDate: json['received_date'] ?? '',
      status: json['status'] ?? '',
    );
  }

  DateTime? get expiry => DateTime.tryParse(expiryDate);

  /// ACTIVE / EXPIRED / DEPLETED. Uses the server's value, falling back to
  /// computing it so the UI still works against an older backend.
  String get status {
    if (_serverStatus.isNotEmpty) return _serverStatus.toUpperCase();
    if (quantity <= 0) return 'DEPLETED';
    final e = expiry;
    if (e != null && e.isBefore(_today)) return 'EXPIRED';
    return 'ACTIVE';
  }

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get isActive => status == 'ACTIVE';
  bool get isExpired => status == 'EXPIRED';
  bool get isDepleted => status == 'DEPLETED';

  /// Days until expiry (negative once expired); null if the date is unknown.
  int? get daysToExpiry {
    final e = expiry;
    if (e == null) return null;
    return DateTime(e.year, e.month, e.day).difference(_today).inDays;
  }

  bool get isExpiringSoon {
    final d = daysToExpiry;
    return isActive && d != null && d <= 30;
  }

  String get statusLabel {
    switch (status) {
      case 'EXPIRED':
        return 'Expired';
      case 'DEPLETED':
        return 'Depleted';
      default:
        return 'Active';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine': medicineId,
      'batch_number': batchNumber,
      if (manufactureDate.isNotEmpty) 'manufacture_date': manufactureDate,
      'expiry_date': expiryDate,
      'quantity': quantity,
      'buying_price': buyingPrice,
      'selling_price': sellingPrice,
      if (supplierId != null) 'supplier': supplierId,
    };
  }
}
