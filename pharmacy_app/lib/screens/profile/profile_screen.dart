import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMovementProvider>().loadMovements();
    });
  }

  bool _isToday(String isoDate) {
    final parsed = DateTime.tryParse(isoDate);
    if (parsed == null) return false;
    final now = DateTime.now();
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final allMovements = context.watch<StockMovementProvider>().movements;
    final inventory = context.watch<InventoryProvider>();

    // "My activity" — scoped to this user, today, matching the design.
    final myMovementsToday = allMovements.where((m) {
      final isMine = user == null || m.performedById == null
          ? true // backend may not always echo performed_by back; don't hide everything if so
          : m.performedById == user.id;
      final today = m.movementDate.isNotEmpty
          ? _isToday(m.movementDate)
          : _isToday(m.date);
      return isMine && today;
    }).toList();

    final updatesToday = myMovementsToday.length;
    final netUnitsToday = myMovementsToday.fold<int>(0, (sum, m) {
      final isIn = m.movementType.toUpperCase() == 'IN';
      return sum + (isIn ? m.quantity : -m.quantity);
    });

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
        children: [
          Text('My activity', style: AppTextStyles.headingLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: AppColors.primary,
                child: Text(
                  _initials(user),
                  style: const TextStyle(
                    color: Color(0xFF06170C),
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName(user),
                      style: AppTextStyles.headingSmall,
                    ),
                    Text(
                      _prettyRole(user?.role),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatBox(value: '$updatesToday', label: 'Updates today'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  value: '${netUnitsToday >= 0 ? '+' : ''}$netUnitsToday',
                  label: 'Net units today',
                  color: netUnitsToday >= 0 ? AppColors.primaryDeep : AppColors.error,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),
          Text('Account', style: AppTextStyles.headingSmall),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Username',
                  value: user?.username.isNotEmpty == true ? user!.username : '—',
                ),
                _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: user?.email.isNotEmpty == true ? user!.email : '—',
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user?.phoneNumber.isNotEmpty == true
                      ? user!.phoneNumber
                      : '—',
                ),
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Role',
                  value: _prettyRole(user?.role),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Today', style: AppTextStyles.headingSmall),
              if (updatesToday > 0)
                Text('$updatesToday entries', style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (myMovementsToday.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No activity recorded yet today.',
                style: AppTextStyles.bodyMedium,
              ),
            )
          else
            ...myMovementsToday.map((m) {
              final isIn = m.movementType.toUpperCase() == 'IN';
              final matches =
                  inventory.medicines.where((med) => med.id == m.medicineId).toList();
              final medName =
                  matches.isNotEmpty ? matches.first.name : 'Medicine #${m.medicineId}';

              return GestureDetector(
                onTap: () => context.push(
                  RouteNames.medicineDetail(m.medicineId),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: isIn ? AppColors.primary : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${isIn ? 'Restocked' : 'Dispensed'} $medName',
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${isIn ? '+' : '-'}${m.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isIn ? AppColors.primaryDeep : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go(RouteNames.login);
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _fullName(User? user) {
    if (user == null) return 'StockRoom User';

    final name = '${user.firstName} ${user.lastName}'.trim();
    if (name.isNotEmpty) return name;
    if (user.username.isNotEmpty) return user.username;
    return 'StockRoom User';
  }

  String _initials(User? user) {
    if (user == null) return 'SR';

    final first = user.firstName.trim();
    final last = user.lastName.trim();

    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (user.username.isNotEmpty) return user.username[0].toUpperCase();
    return 'SR';
  }

  String _prettyRole(String? role) {
    if (role == null || role.isEmpty) return 'Stock Clerk';

    return role
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDeep),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodySmall),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;

  const _StatBox({required this.value, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
