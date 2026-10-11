import 'package:flutter/material.dart';

import '../config/app_colors.dart';

/// A person's photo, or their initials on a green badge when they have none.
class UserAvatar extends StatelessWidget {
  final String? url;
  final String initials;
  final double radius;

  const UserAvatar({
    super.key,
    required this.initials,
    this.url,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final badge = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: const Color(0xFF06170C),
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return badge;

    return ClipOval(
      child: Image.network(
        url!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        cacheWidth: (radius * 6).round(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : badge,
        errorBuilder: (context, error, stack) => badge,
      ),
    );
  }
}
