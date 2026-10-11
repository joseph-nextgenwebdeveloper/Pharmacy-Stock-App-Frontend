class DayMovement {
  final String date;
  final int unitsIn;
  final int unitsOut;

  const DayMovement({
    required this.date,
    required this.unitsIn,
    required this.unitsOut,
  });

  factory DayMovement.fromJson(Map<String, dynamic> json) {
    return DayMovement(
      date: json['date'] ?? '',
      unitsIn: json['units_in'] ?? 0,
      unitsOut: json['units_out'] ?? 0,
    );
  }
}

class Dashboard {
  final int totalMedicines;
  final int totalStock;
  final int healthyStock;
  final int lowStock;
  final int outOfStock;
  final int todayReceived;
  final int todayDispensed;
  final int todaySales;
  final int unreadNotifications;
  final int expiredBatches;
  final int expiringBatches;
  final int myUpdatesToday;
  final List<DayMovement> weeklyMovements;

  const Dashboard({
    required this.totalMedicines,
    required this.totalStock,
    required this.healthyStock,
    required this.lowStock,
    required this.outOfStock,
    required this.todayReceived,
    required this.todayDispensed,
    required this.todaySales,
    required this.unreadNotifications,
    this.expiredBatches = 0,
    this.expiringBatches = 0,
    this.myUpdatesToday = 0,
    this.weeklyMovements = const [],
  });

  factory Dashboard.fromJson(
    Map<String, dynamic> json,
  ) {
    final weekly = json['weekly_movements'];

    return Dashboard(
      totalMedicines: json['total_medicines'] ?? 0,
      totalStock: json['total_stock'] ?? 0,
      healthyStock: json['healthy_stock'] ?? 0,
      lowStock: json['low_stock'] ?? 0,
      outOfStock: json['out_of_stock'] ?? 0,
      todayReceived: json['today_received'] ?? 0,
      todayDispensed: json['today_dispensed'] ?? 0,
      todaySales: json['today_sales'] ?? 0,
      unreadNotifications: json['unread_notifications'] ?? 0,
      expiredBatches: json['expired_batches'] ?? 0,
      expiringBatches: json['expiring_batches'] ?? 0,
      myUpdatesToday: json['my_updates_today'] ?? 0,
      weeklyMovements: weekly is List
          ? weekly
              .whereType<Map>()
              .map((m) => DayMovement.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
    );
  }
}
