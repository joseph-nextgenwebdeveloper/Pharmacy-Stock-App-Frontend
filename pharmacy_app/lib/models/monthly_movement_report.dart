class MonthlyMovementReport {
  final int year;
  final int month;
  final int stockReceived;
  final int stockDispensed;

  const MonthlyMovementReport({
    required this.year,
    required this.month,
    required this.stockReceived,
    required this.stockDispensed,
  });

  factory MonthlyMovementReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return MonthlyMovementReport(
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      stockReceived: json['stock_received'] ?? 0,
      stockDispensed: json['stock_dispensed'] ?? 0,
    );
  }
}