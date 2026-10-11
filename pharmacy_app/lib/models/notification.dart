class AppNotification {
  final int id;
  final int receiverId;
  final int? medicineId;
  final String medicineName;
  final String notificationType;
  final String title;
  final String message;
  final bool isRead;
  final bool isResolved;
  final int reminderCount;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.receiverId,
    this.medicineId,
    this.medicineName = '',
    required this.notificationType,
    required this.title,
    required this.message,
    required this.isRead,
    this.isResolved = false,
    this.reminderCount = 0,
    required this.createdAt,
  });

  factory AppNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppNotification(
      id: json['id'] ?? 0,
      receiverId: json['receiver'] ?? 0,
      medicineId: json['medicine'] as int?,
      medicineName: json['medicine_name'] ?? '',
      notificationType: json['notification_type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      isResolved: json['is_resolved'] ?? false,
      reminderCount: json['reminder_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      receiverId: receiverId,
      medicineId: medicineId,
      medicineName: medicineName,
      notificationType: notificationType,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved,
      reminderCount: reminderCount,
      createdAt: createdAt,
    );
  }
}
