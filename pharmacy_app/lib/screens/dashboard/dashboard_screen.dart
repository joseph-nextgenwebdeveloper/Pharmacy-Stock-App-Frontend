import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/formatter.dart';
import '../../models/medicine.dart';
import '../../models/stock_movement.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

/// Home tab — pulls its headline numbers straight from the backend's
/// /api/dashboard/ endpoint (total stock, healthy/low/out counts, today's
/// received/dispensed/sales), then shows a recent-movements feed underneath.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
      context.read<InventoryProvider>().loadMedicines();
      context.read<CategoryProvider>().loadCategories();
      context.read<StockMovementProvider>().loadMovements();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<DashboardProvider>().refresh(),
      context.read<InventoryProvider>().refresh(),
      context.read<CategoryProvider>().refresh(),
      context.read<StockMovementProvider>().refresh(),
    ]);
  }

  String _greetingName(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return 'there';

    final first = user.firstName.trim();
    if (first.isNotEmpty) return first;
    if (user.username.trim().isNotEmpty) return user.username.trim();
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final inventory = context.watch<InventoryProvider>();
    final movements = context.watch<StockMovementProvider>();

    final loadingFirstTime = dashboard.isLoading && dashboard.dashboard == null;
    final failedFirstTime = dashboard.error != null && dashboard.dashboard == null;

    if (loadingFirstTime) {
      return const LoadingWidget(message: 'Loading your pharmacy...');
    }

    if (failedFirstTime) {
      return AppErrorWidget(
        message: dashboard.error!,
        onRetry: () => context.read<DashboardProvider>().loadDashboard(),
      );
    }

    final summary = dashboard.dashboard;
    final recentMovements = movements.movements.take(6).toList();

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text('Good ${_dayPart()}', style: AppTextStyles.label),
            Text(_greetingName(context), style: AppTextStyles.headingLarge),
            const SizedBox(height: 18),

            Text(
              '${Formatter.number(summary?.totalStock ?? 0)} units in stock',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary?.totalMedicines ?? inventory.medicines.length} SKUs · '
              '+${summary?.todayReceived ?? 0} in / -${summary?.todayDispensed ?? 0} out today',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),

            const SizedBox(height: 18),
            _StockHealthCard(
              healthy: summary?.healthyStock ?? inventory.wellStockedCount,
              total: summary?.totalMedicines ?? inventory.medicines.length,
              lowStock: summary?.lowStock ?? inventory.lowStock.length,
              outOfStock: summary?.outOfStock ?? inventory.outOfStock.length,
              onSeeAlerts: () => context.go(RouteNames.alerts),
              onSeeAllMedicines: () => context.go(RouteNames.inventory),
              onSeeBatches: () => context.push(RouteNames.batches),
            ),

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Today\'s sales',
                    value: '${summary?.todaySales ?? 0}',
                    icon: Icons.point_of_sale_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    label: 'Unread alerts',
                    value: '${summary?.unreadNotifications ?? 0}',
                    icon: Icons.notifications_none_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('Movement calendar', style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            _MovementCalendar(
              movements: movements.movements,
              medicines: inventory.medicines,
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent movements', style: AppTextStyles.headingSmall),
                TextButton(
                  onPressed: () => context.go(RouteNames.movementHistory),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 4),

            if (movements.isLoading && recentMovements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (recentMovements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No stock movements recorded yet.',
                  style: AppTextStyles.bodyMedium,
                ),
              )
            else
              ...recentMovements.map((m) {
                final matches = inventory.medicines
                    .where((med) => med.id == m.medicineId)
                    .toList();
                final medName =
                    matches.isNotEmpty ? matches.first.name : 'Medicine #${m.medicineId}';
                final isIn = m.movementType.toUpperCase() == 'IN';

                return GestureDetector(
                  onTap: () =>
                      context.push(RouteNames.medicineDetail(m.medicineId)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isIn
                                ? AppColors.successSoft
                                : AppColors.errorSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIn
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 17,
                            color: isIn ? AppColors.primaryDeep : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            medName,
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
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(label, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockHealthCard extends StatelessWidget {
  final int healthy;
  final int total;
  final int lowStock;
  final int outOfStock;
  final VoidCallback onSeeAlerts;
  final VoidCallback onSeeAllMedicines;
  final VoidCallback onSeeBatches;

  const _StockHealthCard({
    required this.healthy,
    required this.total,
    required this.lowStock,
    required this.outOfStock,
    required this.onSeeAlerts,
    required this.onSeeAllMedicines,
    required this.onSeeBatches,
  });

  double get _ratio => total == 0 ? 0 : healthy / total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded,
                  color: AppColors.primary, size: 17),
              const SizedBox(width: 8),
              const Text(
                'Stock Health',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                SizedBox(
                  width: 170,
                  height: 90,
                  child: CustomPaint(painter: _GaugePainter(ratio: _ratio)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      Text(
                        '$healthy',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'of $total well stocked',
                        style: const TextStyle(
                          color: Color(0xFFB9BEB9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onSeeAlerts,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$outOfStock out of stock · $lowStock running low',
                    style: const TextStyle(
                      color: Color(0xFFB9BEB9),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Text(
                  'View alerts',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3E3A)),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: onSeeAllMedicines,
                  child: const Text('All medicines',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A3E3A)),
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: onSeeBatches,
                  child: const Text('Batches',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;

  _GaugePainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 6;

    final bg = Paint()
      ..color = const Color(0xFF2A2E2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const start = 3.14159265;
    const sweep = 3.14159265;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      bg,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep * ratio.clamp(0.0, 1.0).toDouble(),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}

/// Month calendar of stock movements — computed entirely client-side from
/// the (now fully-paginated) movements list, so it needs no backend
/// changes. Tap a day to see that day's moves and per-medicine totals.
class _MovementCalendar extends StatefulWidget {
  final List<StockMovement> movements;
  final List<Medicine> medicines;

  const _MovementCalendar({
    required this.movements,
    required this.medicines,
  });

  @override
  State<_MovementCalendar> createState() => _MovementCalendarState();
}

class _MovementCalendarState extends State<_MovementCalendar> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  bool _initialised = false;

  DateTime? _dateOf(StockMovement m) {
    final raw = m.movementDate.isNotEmpty ? m.movementDate : m.date;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _initialiseIfNeeded() {
    if (_initialised) return;
    _initialised = true;

    DateTime? mostRecent;
    for (final m in widget.movements) {
      final d = _dateOf(m);
      if (d != null && (mostRecent == null || d.isAfter(mostRecent))) {
        mostRecent = d;
      }
    }

    final anchor = mostRecent ?? DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month);
    _selectedDay = anchor;
  }

  Map<DateTime, List<StockMovement>> _groupedByDay() {
    final map = <DateTime, List<StockMovement>>{};
    for (final m in widget.movements) {
      final d = _dateOf(m);
      if (d == null) continue;
      map.putIfAbsent(d, () => []).add(m);
    }
    return map;
  }

  String _medicineName(int medicineId) {
    final matches = widget.medicines.where((m) => m.id == medicineId).toList();
    return matches.isNotEmpty ? matches.first.name : 'Medicine #$medicineId';
  }

  @override
  Widget build(BuildContext context) {
    _initialiseIfNeeded();

    final byDay = _groupedByDay();
    final maxMovesInMonth = byDay.entries
        .where((e) =>
            e.key.year == _visibleMonth.year && e.key.month == _visibleMonth.month)
        .fold<int>(0, (max, e) => e.value.length > max ? e.value.length : max);

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Monday-first weekday index (0 = Monday ... 6 = Sunday).
    final leadingBlanks = (firstOfMonth.weekday + 6) % 7;

    final selectedMoves = byDay[DateTime(
          _selectedDay.year,
          _selectedDay.month,
          _selectedDay.day,
        )] ??
        [];

    final inTotal = selectedMoves
        .where((m) => m.movementType.toUpperCase() == 'IN')
        .fold<int>(0, (sum, m) => sum + m.quantity);
    final outTotal = selectedMoves
        .where((m) => m.movementType.toUpperCase() == 'OUT')
        .fold<int>(0, (sum, m) => sum + m.quantity);

    // Net delta per medicine for the selected day, for the bar list.
    final netByMedicine = <int, int>{};
    for (final m in selectedMoves) {
      final isIn = m.movementType.toUpperCase() == 'IN';
      netByMedicine.update(
        m.medicineId,
        (v) => v + (isIn ? m.quantity : -m.quantity),
        ifAbsent: () => isIn ? m.quantity : -m.quantity,
      );
    }
    final maxAbsDelta = netByMedicine.values.fold<int>(
      1,
      (max, v) => v.abs() > max ? v.abs() : max,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 18),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _monthName(_visibleMonth.month),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: leadingBlanks + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leadingBlanks) return const SizedBox.shrink();

              final day = index - leadingBlanks + 1;
              final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
              final moves = byDay[date] ?? [];
              final isSelected = date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;

              Color? bg;
              Color fg = AppColors.textPrimary;

              if (isSelected) {
                bg = AppColors.dark;
                fg = Colors.white;
              } else if (moves.isNotEmpty) {
                final isHot = maxMovesInMonth > 0 &&
                    moves.length >= maxMovesInMonth * 0.5;
                bg = isHot ? AppColors.primary : AppColors.successSoft;
                fg = isHot ? const Color(0xFF06170C) : AppColors.primaryDeep;
              }

              return Padding(
                padding: const EdgeInsets.all(2),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${_selectedDay.day} ${_monthName(_selectedDay.month)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${selectedMoves.length} moves',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              const Spacer(),
              Text('IN ', style: AppTextStyles.bodySmall),
              Text('$inTotal',
                  style: const TextStyle(
                      color: AppColors.primaryDeep, fontWeight: FontWeight.w800)),
              Text('  OUT ', style: AppTextStyles.bodySmall),
              Text('$outTotal',
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w800)),
            ],
          ),
          if (netByMedicine.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...netByMedicine.entries.map((entry) {
              final isPositive = entry.value >= 0;
              final ratio = entry.value.abs() / maxAbsDelta;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _medicineName(entry.key),
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${isPositive ? '+' : ''}${entry.value}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: isPositive ? AppColors.primaryDeep : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(
                          isPositive ? AppColors.primary : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No movements on this day.',
                style: AppTextStyles.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month - 1];
  }
}
