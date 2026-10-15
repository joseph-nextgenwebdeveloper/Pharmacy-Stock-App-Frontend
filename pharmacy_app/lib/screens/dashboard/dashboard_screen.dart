import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/activity_report_actions.dart';
import '../../helpers/formatter.dart';
import '../../helpers/print_helpers.dart';
import '../../models/activity_report.dart';
import '../../models/dashboard.dart';
import '../../models/medicine.dart';
import '../../providers/auth_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../routes/route_names.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/medicine_image.dart';
import '../../widgets/movement_bars.dart';
import '../../widgets/movement_calendar.dart';
import '../../widgets/user_avatar.dart';

/// Home tab — stock health, the week at a glance, one-tap PDF reports, the
/// movement calendar (with a full day view) and the latest movements.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// 0 = all medicines, 1.. = one category (the pager on the health card).
  int _categoryIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().loadDashboard();
      context.read<InventoryProvider>().loadMedicines();
      context.read<CategoryProvider>().loadCategories();
      context.read<StockMovementProvider>().loadMovements();
      context.read<BatchProvider>().loadBatches();
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

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Future<void> _pickDatesAndDownload() async {
    final range = await pickReportRange(context);
    if (range == null || !mounted) return;

    await downloadActivityReport(
      context,
      period: ActivityReport.custom,
      start: range.start,
      end: range.end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final inventory = context.watch<InventoryProvider>();
    final movements = context.watch<StockMovementProvider>();
    final categories = context.watch<CategoryProvider>().categories;
    final user = context.watch<AuthProvider>().user;

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

    // ---- health numbers for the selected category ----
    final catIndex = _categoryIndex.clamp(0, categories.length).toInt();
    final category = catIndex == 0 ? null : categories[catIndex - 1];

    int healthy, total, low, out;
    if (category == null && summary != null) {
      healthy = summary.healthyStock;
      total = summary.totalMedicines;
      low = summary.lowStock;
      out = summary.outOfStock;
    } else {
      final List<Medicine> scoped = category == null
          ? inventory.medicines
          : inventory.medicines
              .where((m) => m.categoryId == category.id)
              .toList();
      healthy = scoped.where((m) => m.quantity > m.reorderLevel).length;
      total = scoped.length;
      out = scoped.where((m) => m.quantity <= 0).length;
      low = scoped
          .where((m) => m.quantity > 0 && m.quantity <= m.reorderLevel)
          .length;
    }

    // Reorder alerts always count the whole stock.
    final flaggedLow = summary?.lowStock ?? inventory.lowStock.length;
    final flaggedOut = summary?.outOfStock ?? inventory.outOfStock.length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            // ---------------------------------------------------- header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, d MMM').format(DateTime.now()),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(RouteNames.alerts),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.notifications_none_rounded,
                            size: 21),
                      ),
                      if ((summary?.unreadNotifications ?? 0) > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.background, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.go(RouteNames.profile),
                  child: UserAvatar(
                    initials: user?.initials ?? '?',
                    url: user?.avatarUrl,
                    radius: 21,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Text('Good ${_dayPart()}', style: AppTextStyles.label),
            Text(_greetingName(context), style: AppTextStyles.headingLarge),

            // ------------------------------------------------ big number
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        text: Formatter.number(summary?.totalStock ?? 0),
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        children: [
                          TextSpan(
                            text: ' units',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('In stock', style: AppTextStyles.label),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _weeklyLine(summary),

            // ------------------------------------------- stock health
            const SizedBox(height: 18),
            _StockHealthCard(
              healthy: healthy,
              total: total,
              low: low,
              out: out,
              categoryName: category?.name ?? 'All medicines',
              canPage: categories.isNotEmpty,
              onPrev: () => setState(() => _categoryIndex =
                  catIndex == 0 ? categories.length : catIndex - 1),
              onNext: () => setState(() => _categoryIndex =
                  catIndex >= categories.length ? 0 : catIndex + 1),
              onSeeAllMedicines: () => context.go(RouteNames.inventory),
              onSeeBatches: () => context.push(RouteNames.batches),
            ),

            // ---------------------------------------- reorder alerts
            const SizedBox(height: 22),
            Row(
              children: [
                Text('Reorder alerts', style: AppTextStyles.headingSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go(RouteNames.alerts),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.primaryDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ReorderCard(
              low: flaggedLow,
              out: flaggedOut,
              expired: summary?.expiredBatches ?? 0,
              expiring: summary?.expiringBatches ?? 0,
              onTap: () => context.go(RouteNames.alerts),
            ),

            // ------------------------------------------- today numbers
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Received today',
                    value: '+${Formatter.number(summary?.todayReceived ?? 0)}',
                    icon: Icons.south_west_rounded,
                    color: AppColors.primaryDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniStat(
                    label: 'Dispensed today',
                    value: '-${Formatter.number(summary?.todayDispensed ?? 0)}',
                    icon: Icons.north_east_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),

            // ------------------------------------------- last 7 days
            if (summary != null && summary.weeklyMovements.isNotEmpty) ...[
              const SizedBox(height: 22),
              _WeekCard(summary: summary),
            ],

            // ----------------------------------------------- reports
            const SizedBox(height: 22),
            _ReportsCard(
              onToday: () => downloadActivityReport(
                context,
                period: ActivityReport.day,
                date: DateTime.now(),
              ),
              onWeek: () => downloadActivityReport(
                context,
                period: ActivityReport.week,
                date: DateTime.now(),
              ),
              onMonth: () => downloadActivityReport(
                context,
                period: ActivityReport.month,
                date: DateTime.now(),
              ),
              onPick: _pickDatesAndDownload,
              onOpen: () => context.push(RouteNames.activityReport),
            ),

            // ------------------------------------------- calendar
            const SizedBox(height: 24),
            Text('Movement calendar', style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            MovementCalendar(
              movements: movements.movements,
              medicines: inventory.medicines,
              onDownloadDay: (day) => downloadActivityReport(
                context,
                period: ActivityReport.day,
                date: day,
              ),
              onPrintDay: (day, moves) => printDayReport(context, day, moves),
            ),

            // --------------------------------------- recent movements
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
                final medName = matches.isNotEmpty
                    ? matches.first.name
                    : (m.medicineName.isNotEmpty
                        ? m.medicineName
                        : 'Medicine #${m.medicineId}');
                final isIn = m.isIn;

                return GestureDetector(
                  onTap: () =>
                      context.push(RouteNames.medicineDetail(m.medicineId)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        MedicineImage(
                          url: matches.isNotEmpty ? matches.first.imageUrl : null,
                          size: 42,
                          radius: 12,
                          background:
                              isIn ? AppColors.successSoft : AppColors.errorSoft,
                          iconColor:
                              isIn ? AppColors.primaryDeep : AppColors.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medName,
                                style: AppTextStyles.bodyMedium
                                    .copyWith(fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${m.label} · ${m.who} · ${Formatter.timeAgo(m.movementDate)}',
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${isIn ? '+' : '-'}${m.quantity}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isIn ? AppColors.primaryDeep : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
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

  /// "312 dispensed this week  ▾ 8%"
  Widget _weeklyLine(Dashboard? summary) {
    final dispensed = summary?.weekDispensed ?? 0;
    final trend = summary?.dispensedTrendPercent;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          '${Formatter.number(dispensed)} dispensed this week',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary),
        ),
        if (trend != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: trend <= 0 ? AppColors.successSoft : AppColors.warningSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  trend <= 0
                      ? Icons.arrow_drop_down_rounded
                      : Icons.arrow_drop_up_rounded,
                  size: 18,
                  color: trend <= 0 ? AppColors.primaryDeep : AppColors.warning,
                ),
                Text(
                  '${trend.abs()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: trend <= 0 ? AppColors.primaryDeep : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ======================================================================
// Pieces
// ======================================================================

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderCard extends StatelessWidget {
  final int low;
  final int out;
  final int expired;
  final int expiring;
  final VoidCallback onTap;

  const _ReorderCard({
    required this.low,
    required this.out,
    required this.expired,
    required this.expiring,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final flagged = low + out;
    final bad = flagged > 0 || expired > 0;

    final parts = <String>[
      if (out > 0) '$out out of stock',
      if (low > 0) '$low running low',
      if (expired > 0) '$expired expired',
      if (expiring > 0) '$expiring expiring soon',
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bad ? AppColors.errorSoft : AppColors.surface,
          border: Border.all(
            color: bad ? AppColors.errorBorder : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bad ? AppColors.errorTile : AppColors.successSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                bad ? Icons.warning_amber_rounded : Icons.check_rounded,
                color: bad ? AppColors.error : AppColors.primaryDeep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flagged == 0
                        ? 'Nothing below reorder level'
                        : '$flagged ${flagged == 1 ? 'item' : 'items'} need reordering',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.isEmpty
                        ? 'Every medicine is above its reorder level.'
                        : parts.join(' · '),
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            if (flagged > 0)
              Text(
                '$flagged',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: AppColors.error,
                ),
              ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final Dashboard summary;

  const _WeekCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = summary.weeklyMovements;

    String letter(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? '' : DateFormat('E').format(d);
    }

    bool isToday(String iso) {
      final d = DateTime.tryParse(iso);
      return d != null &&
          d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Last 7 days', style: AppTextStyles.headingSmall),
              ),
              Text(
                '+${Formatter.number(summary.weekReceived)} in · '
                '-${Formatter.number(summary.weekDispensed)} out',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 14),
          MovementBars(
            data: [
              for (final d in days)
                BarDatum(
                  label: letter(d.date),
                  unitsIn: d.unitsIn,
                  unitsOut: d.unitsOut,
                  highlight: isToday(d.date),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _dot(AppColors.primary),
              const SizedBox(width: 5),
              Text('Received', style: AppTextStyles.bodySmall),
              const SizedBox(width: 14),
              _dot(AppColors.error),
              const SizedBox(width: 5),
              Text('Dispensed / removed', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

class _ReportsCard extends StatelessWidget {
  final VoidCallback onToday;
  final VoidCallback onWeek;
  final VoidCallback onMonth;
  final VoidCallback onPick;
  final VoidCallback onOpen;

  const _ReportsCard({
    required this.onToday,
    required this.onWeek,
    required this.onMonth,
    required this.onPick,
    required this.onOpen,
  });

  Widget _pill(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                'PDF reports',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Everything received, dispensed and changed - tap a period to '
            'download it.',
            style: TextStyle(
              color: AppColors.onDarkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Today', Icons.today_rounded, onToday),
              _pill('This week', Icons.date_range_rounded, onWeek),
              _pill('This month', Icons.calendar_month_rounded, onMonth),
              _pill('Pick dates', Icons.edit_calendar_rounded, onPick),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onOpen,
            child: const Row(
              children: [
                Text(
                  'Open report dashboard',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 18),
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
  final int low;
  final int out;
  final String categoryName;
  final bool canPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onSeeAllMedicines;
  final VoidCallback onSeeBatches;

  const _StockHealthCard({
    required this.healthy,
    required this.total,
    required this.low,
    required this.out,
    required this.categoryName,
    required this.canPage,
    required this.onPrev,
    required this.onNext,
    required this.onSeeAllMedicines,
    required this.onSeeBatches,
  });

  double get _ratio => total == 0 ? 0 : healthy / total;

  Widget _pagerButton(IconData icon, bool filled, VoidCallback onTap) {
    return GestureDetector(
      onTap: canPage ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled ? const Color(0xFF06170C) : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_outlined,
                    size: 17, color: AppColors.primaryDeep),
              ),
              const SizedBox(width: 10),
              const Text(
                'Stock Health',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 118,
            width: 230,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _GaugePainter(ratio: _ratio)),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Well stocked', style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: Formatter.number(healthy),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                          children: [
                            TextSpan(
                              text: ' / ${Formatter.number(total)}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              children: [
                _pagerButton(Icons.chevron_left_rounded, false, onPrev),
                Expanded(
                  child: Text(
                    categoryName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                _pagerButton(Icons.chevron_right_rounded, true, onNext),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$out out of stock · $low running low',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: onSeeAllMedicines,
                  child: const Text('All medicines',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                  ),
                  onPressed: onSeeBatches,
                  child: const Text('Batches',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
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
    const stroke = 15.0;
    final radius = size.width / 2 - stroke;
    final center = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    const start = 3.14159265;
    const sweep = 3.14159265;

    canvas.drawArc(rect, start, sweep, false, bg);

    final value = ratio.clamp(0.0, 1.0).toDouble();
    if (value > 0) {
      canvas.drawArc(rect, start, sweep * value, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.ratio != ratio;
}
