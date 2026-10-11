import 'medicine.dart';

/// One "who did what" entry from the activity feed.
class ActivityLog {
  final int id;
  final int? userId;
  final String userName;
  final String userRole;
  final String? userAvatar;
  final String action;
  final String actionLabel;
  final String summary;
  final String targetType;
  final int? targetId;
  final String targetLabel;

  /// Signed units for stock actions (+in / -out); null for everything else.
  final int? quantity;

  /// Extra detail: {"field": {"from":..,"to":..}} for edits, or batch /
  /// reason / reference / balance before-after for stock actions.
  final Map<String, dynamic> changes;
  final String createdAt;

  const ActivityLog({
    required this.id,
    this.userId,
    this.userName = '',
    this.userRole = '',
    this.userAvatar,
    required this.action,
    this.actionLabel = '',
    required this.summary,
    this.targetType = '',
    this.targetId,
    this.targetLabel = '',
    this.quantity,
    this.changes = const {},
    required this.createdAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];

    return ActivityLog(
      id: json['id'] ?? 0,
      userId: json['user'] as int?,
      userName: json['user_name'] ?? '',
      userRole: json['user_role'] ?? '',
      userAvatar: Medicine.resolveImageUrl(json['user_avatar'] as String?),
      action: json['action'] ?? '',
      actionLabel: json['action_label'] ?? '',
      summary: json['summary'] ?? '',
      targetType: json['target_type'] ?? '',
      targetId: json['target_id'] as int?,
      targetLabel: json['target_label'] ?? '',
      quantity: json['quantity'] as int?,
      changes: rawChanges is Map ? Map<String, dynamic>.from(rawChanges) : const {},
      createdAt: json['created_at'] ?? '',
    );
  }

  DateTime? get when => DateTime.tryParse(createdAt)?.toLocal();

  bool get isStock => action == 'STOCK_IN' || action == 'STOCK_OUT';

  bool get isSession => action == 'LOGIN' || action == 'LOGOUT';

  String get who => userName.isNotEmpty ? userName : 'System';
}

/// Headline numbers for the profile / My activity screen.
class ActivitySummary {
  final int updatesToday;
  final int netUnitsToday;
  final int unitsInToday;
  final int unitsOutToday;
  final int updates7d;
  final int netUnits7d;
  final int unitsIn7d;
  final int unitsOut7d;
  final String? lastAction;
  final String? lastActionAt;

  const ActivitySummary({
    this.updatesToday = 0,
    this.netUnitsToday = 0,
    this.unitsInToday = 0,
    this.unitsOutToday = 0,
    this.updates7d = 0,
    this.netUnits7d = 0,
    this.unitsIn7d = 0,
    this.unitsOut7d = 0,
    this.lastAction,
    this.lastActionAt,
  });

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    return ActivitySummary(
      updatesToday: json['updates_today'] ?? 0,
      netUnitsToday: json['net_units_today'] ?? 0,
      unitsInToday: json['units_in_today'] ?? 0,
      unitsOutToday: json['units_out_today'] ?? 0,
      updates7d: json['updates_7d'] ?? 0,
      netUnits7d: json['net_units_7d'] ?? 0,
      unitsIn7d: json['units_in_7d'] ?? 0,
      unitsOut7d: json['units_out_7d'] ?? 0,
      lastAction: json['last_action'] as String?,
      lastActionAt: json['last_action_at'] as String?,
    );
  }
}

/// A member of staff (for the "who did it" filter).
class StaffMember {
  final int id;
  final String name;
  final String role;
  final String? avatar;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    this.avatar,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? json['username'] ?? '',
      role: json['role'] ?? '',
      avatar: Medicine.resolveImageUrl(json['avatar'] as String?),
    );
  }
}
