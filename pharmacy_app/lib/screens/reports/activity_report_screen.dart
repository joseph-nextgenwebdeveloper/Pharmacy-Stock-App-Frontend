import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/activity_report_actions.dart';
import '../../helpers/formatter.dart';
import '../../models/activity_report.dart';
import '../../models/user.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../widgets/movement_bars.dart';

/// Movement & activity dashboard for ANY period — a day, a week, a month or
/// a custom range — with a one-tap PDF download / print.
class ActivityReportScreen extends StatefulWidget {
  /// Opens on this period (day / week / month / custom).
  final String initialPeriod;

  const ActivityReportScreen({
    super.key,
    this.initialPeriod = ActivityReport.week,
  });

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  late String _period;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _custom;

  ActivityReport? _report;
  bool _loading = true;
  int _ticket = 0; // ignores answers from an older request

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Saved movements are the offline fallback for the report.
      context.read<StockMovementProvider>().loadMovements();
      context.read<InventoryProvider>().loadMedicines();
      _load();
    });
  }

  Future<void> _load() async {
    final ticket = ++_ticket;
    setState(() => _loading = true);

    final report = await loadActivityReport(
      context,
      period: _period,
      date: _anchor,
      start: _custom?.start,
      end: _custom?.end,
    );

    if (!mounted || ticket != _ticket) return;
    setState(() {
      _report = report;
      _loading = false;
    });
  }

  Future<void> _setPeriod(String period) async {
    if (period == ActivityReport.custom && _custom == null) {
      final picked = await pickReportRange(context);
      if (picked == null || !mounted) return;
      _custom = picked;
    }

    setState(() => _period = period);
    _load();
  }

  Future<void> _pickDate() async {
    if (_period == ActivityReport.custom) {
      final picked = await pickReportRange(context, initial: _custom);
      if (picked == null || !mounted) return;
      setState(() => _custom = picked);
      _load();
      return;
    }

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _anchor = picked);
    _load();
  }

  void _step(int direction) {
    if (_period == ActivityReport.custom) return;

    setState(() {
      switch (_period) {
        case ActivityReport.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case ActivityReport.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
        default:
          _anchor = _anchor.add(Duration(days: direction));
      }
    });
    _load();
  }

  bool get _atPresent {
    if (_period == ActivityReport.custom) return true;
    final (_, end) = ActivityReport.rangeFor(_period, _anchor);
    return !end.isBefore(ActivityReport.dayOnly(DateTime.now()));
  }

  String get _rangeLabel {
    final (s, e) = ActivityReport.rangeFor(
      _period,
      _anchor,
      customStart: _custom?.start,
      customEnd: _custom?.end,
    );
    return ActivityReport.labelFor(_period, s, e);
  }

  Future<void> _output(ReportOutput output) async {
    await downloadActivityReport(
      context,
      period: _period,
      date: _anchor,
      start: _custom?.start,
      end: _custom?.end,
      output: output,
      ready: _report,
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Movement & activity', style: AppTextStyles.headingMedium),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _periodPills(),
              const SizedBox(height: 12),
              _rangeBar(),
              const SizedBox(height: 16),
              if (_loading && report == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (report != null) ...[
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
                if (!report.fromServer) _offlineNote(),
                _summary(report),
                const SizedBox(height: 14),
                if (report.daily.length > 1) _dailyCard(report),
                if (report.byMedicine.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _medicinesCard(report),
                ],
                if (report.byStaff.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _staffCard(report),
                ],
                if (report.activities.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _activityCard(report),
                ],
                if (report.isEmpty) _emptyNote(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _output(ReportOutput.download),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 19),
                        label: const Text('Download PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _output(ReportOutput.print),
                        icon: const Icon(Icons.print_outlined, size: 19),
                        label: const Text('Print'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pieces

  Widget _periodPills() {
    const items = [
      (ActivityReport.day, 'Day'),
      (ActivityReport.week, 'Week'),
      (ActivityReport.month, 'Month'),
      (ActivityReport.custom, 'Custom'),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _setPeriod(items[i].$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _period == items[i].$1
                      ? AppColors.dark
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _period == items[i].$1
                        ? AppColors.dark
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  items[i].$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: _period == items[i].$1
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? AppColors.border : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _rangeBar() {
    final custom = _period == ActivityReport.custom;

    return Row(
      children: [
        _roundButton(Icons.chevron_left_rounded, custom ? null : () => _step(-1)),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 17, color: AppColors.primaryDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _rangeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _roundButton(
          Icons.chevron_right_rounded,
          (custom || _atPresent) ? null : () => _step(1),
        ),
      ],
    );
  }

  Widget _card({required String title, String? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.headingSmall)),
              if (trailing != null)
                Text(trailing, style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 21, color: fg),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(ActivityReport r) {
    final net = r.net;

    return Column(
      children: [
        Row(
          children: [
            _stat('Received', '+${Formatter.number(r.unitsIn)}',
                AppColors.successSoft, AppColors.primaryDeep),
            const SizedBox(width: 10),
            _stat('Dispensed / removed', '-${Formatter.number(r.unitsOut)}',
                AppColors.errorSoft, AppColors.error),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat(
              'Net change',
              '${net > 0 ? '+' : (net < 0 ? '-' : '')}${Formatter.number(net.abs())}',
              AppColors.surface,
              AppColors.textPrimary,
            ),
            const SizedBox(width: 10),
            _stat(
              'Movements',
              Formatter.number(r.movementCount),
              AppColors.surface,
              AppColors.textPrimary,
            ),
            const SizedBox(width: 10),
            _stat(
              'Medicines',
              Formatter.number(r.medicinesTouched),
              AppColors.surface,
              AppColors.textPrimary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _dailyCard(ActivityReport r) {
    final today = ActivityReport.dayOnly(DateTime.now());
    final month = r.period == ActivityReport.month;

    return _card(
      title: 'Day by day',
      trailing: 'green in · red out',
      child: MovementBars(
        data: [
          for (final d in r.daily)
            BarDatum(
              label: month ? '${d.date.day}' : DateFormat('E').format(d.date),
              unitsIn: d.unitsIn,
              unitsOut: d.unitsOut,
              highlight: d.date == today,
            ),
        ],
      ),
    );
  }

  Widget _medicinesCard(ActivityReport r) {
    final top = r.byMedicine.take(8).toList();
    var peak = 1;
    for (final m in top) {
      if (m.total > peak) peak = m.total;
    }

    return _card(
      title: 'Busiest medicines',
      trailing: '${r.byMedicine.length} in total',
      child: Column(
        children: [
          for (final m in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.medicine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (m.unitsIn > 0)
                        Text('+${m.unitsIn}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDeep)),
                      if (m.unitsIn > 0 && m.unitsOut > 0)
                        const SizedBox(width: 8),
                      if (m.unitsOut > 0)
                        Text('-${m.unitsOut}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          if (m.unitsIn > 0)
                            Expanded(
                              flex: (m.unitsIn * 1000 ~/ peak).clamp(1, 1000).toInt(),
                              child: Container(color: AppColors.primary),
                            ),
                          if (m.unitsOut > 0)
                            Expanded(
                              flex: (m.unitsOut * 1000 ~/ peak).clamp(1, 1000).toInt(),
                              child: Container(color: AppColors.error),
                            ),
                          Expanded(
                            flex: (1000 - (m.total * 1000 ~/ peak)).clamp(0, 1000).toInt() + 1,
                            child: Container(color: AppColors.border),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _staffCard(ActivityReport r) {
    return _card(
      title: 'Who did what',
      trailing: r.scope == 'team' ? 'whole team' : null,
      child: Column(
        children: [
          for (final s in r.byStaff)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.successSoft,
                    child: Text(
                      s.name.isEmpty ? '?' : s.name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '${User.prettyRoleName(s.role)} · ${s.moves} movement${s.moves == 1 ? '' : 's'}',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${s.unitsIn} / -${s.unitsOut}',
                    style: AppTextStyles.bodySmall
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _activityCard(ActivityReport r) {
    final shown = r.activities.take(12).toList();
    final time = DateFormat(r.start == r.end ? 'HH:mm' : 'd MMM HH:mm');

    return _card(
      title: 'Other activity',
      trailing: r.scope == 'team' ? 'whole team' : 'yours',
      child: Column(
        children: [
          for (final a in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 74,
                    child: Text(
                      a.at == null ? '--' : time.format(a.at!),
                      style: AppTextStyles.bodySmall
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${a.by.isEmpty ? '' : '${a.by}: '}${a.summary}',
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          if (r.activities.length > shown.length)
            Text(
              '+ ${r.activities.length - shown.length} more in the PDF',
              style: AppTextStyles.bodySmall,
            ),
        ],
      ),
    );
  }

  Widget _offlineNote() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Could not reach the server, so this is built from the data saved '
          'on this phone. It may miss very recent changes.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
        ),
      );

  Widget _emptyNote() => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_available_outlined,
                  size: 32, color: AppColors.textSecondary),
              const SizedBox(height: 6),
              Text('Nothing was recorded in this period.',
                  style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      );
}
