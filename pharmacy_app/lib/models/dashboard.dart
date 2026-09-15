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
  });

  factory Dashboard.fromJson(
    Map<String, dynamic> json,
  ) {
    return Dashboard(
      totalMedicines: json['total_medicines'] ?? 0,
      totalStock: json['total_stock'] ?? 0,
      healthyStock: json['healthy_stock'] ?? 0,
      lowStock: json['low_stock'] ?? 0,
      outOfStock: json['out_of_stock'] ?? 0,
      todayReceived: json['today_received'] ?? 0,
      todayDispensed: json['today_dispensed'] ?? 0,
      todaySales: json['today_sales'] ?? 0,
      unreadNotifications:
          json['unread_notifications'] ?? 0,
    );
  }
}