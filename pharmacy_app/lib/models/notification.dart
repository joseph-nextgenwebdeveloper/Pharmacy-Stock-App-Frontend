class AppNotification {
  final int id;
  final int receiverId;
  final String notificationType;
  final String title;
  final String message;
  final bool isRead;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.receiverId,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppNotification(
      id: json['id'] ?? 0,
      receiverId: json['receiver'] ?? 0,
      notificationType:
          json['notification_type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}