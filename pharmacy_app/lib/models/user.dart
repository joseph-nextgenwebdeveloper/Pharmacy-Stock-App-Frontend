import 'medicine.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String role;

  /// Profile photo URL (null = show the initials badge).
  final String? avatarUrl;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.role,
    this.avatarUrl,
  });

  factory User.fromJson(
    Map<String, dynamic> json,
  ) {
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      role: json['role'] ?? '',
      avatarUrl: Medicine.resolveImageUrl(json['avatar'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone_number': phoneNumber,
      'role': role,
      'avatar': avatarUrl,
    };
  }

  String get fullName {
    return '$firstName $lastName'.trim();
  }

  /// Name to show people: full name, else username.
  String get displayName => fullName.isNotEmpty ? fullName : username;

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();

    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (username.isNotEmpty) return username[0].toUpperCase();
    return '?';
  }

  String get prettyRole => prettyRoleName(role);

  /// Admins and store managers may look at everyone's activity.
  bool get canViewTeamActivity => role == 'ADMIN' || role == 'STORE_MANAGER';

  static String prettyRoleName(String? role) {
    if (role == null || role.isEmpty) return 'Stock Clerk';

    return role
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
