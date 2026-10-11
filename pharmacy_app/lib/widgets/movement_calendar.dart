import 'package:flutter/material.dart';

import 'movement_details.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/app_text_styles.dart';
import '../models/medicine.dart';
import '../models/stock_movement.dart';
import 'medicine_image.dart';

/// Month calendar of stock movements plus a full "what happened on this
/// day" view: totals, per-medicine breakdown and a time-ordered timeline.
/// Everything is computed client-side from the movements list.
class MovementCalendar extends StatefulWidget {
  final List<StockMovement> movements;
  final List<Medicine> medicines;

  /// Called when the person taps "Print day report".
  final void Function(DateTime day, List<StockMovement> moves)? onPrintDay;

  const MovementCalendar({
    super.key,
    required this.movements,
    required this.medicines,
    this.onPrintDay,
  });

  @override
  State<MovementCalendar> createState() => _MovementCalendarState();
}

class _MovementCalendarState extends State<MovementCalendar> {
  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  bool _initialised = false;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _initialiseIfNeeded() {
    if (_initialised) return;
    _initialised = true;

    // Open on today; if nothing happened today but there is history, open
    // on the most recent day that has activity.
    final today = _dayOnly(DateTime.now());
    DateTime anchor = today;

    final hasToday = widget.movements.any((m) => m.day == today);
    if (!hasToday) {
      DateTime? latest;
      for (final m in widget.movements) {
        final d = m.day;
        if (d != null && (latest == null || d.isAfter(latest))) latest = d;
      }
      if (latest != null) anchor = latest;
    }

    _visibleMonth = DateTime(anchor.year, anchor.month);
    _selectedDay = anchor;
  }

  Map<DateTime, List<StockMovement>> _groupedByDay() {
    final map = <DateTime, List<StockMovement>>{};
    for (final m in widget.movements) {
      final d = m.day;
      if (d == null) continue;
      map.putIfAbsent(d, () => []).add(m);
    }
    return map;
  }

  Medicine? _medicine(int id) {
    for (final m in widget.medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  String _name(StockMovement m) {
    if (m.medicineName.isNotEmpty) return m.medicineName;
    return _medicine(m.medicineId)?.name ?? 'Medicine #${m.medicineId}';
  }

  @override
  Widget build(BuildContext context) {
    _initialiseIfNeeded();

    final byDay = _groupedByDay();
    final today = _dayOnly(DateTime.now());

    // ---- month stats ----
    var monthIn = 0, monthOut = 0, monthMoves = 0, busiest = 0;
    byDay.forEach((day, moves) {
      if (day.year == _visibleMonth.year && day.month == _visibleMonth.month) {
        monthMoves += moves.length;
        if (moves.length > busiest) busiest = moves.length;
        for (final m in moves) {
          if (m.isIn) {
            monthIn += m.quantity;
          } else {
            monthOut += m.quantity;
          }
        }
      }
    });

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday + 6) % 7; // Monday first

    final selectedMoves = [...(byDay[_dayOnly(_selectedDay)] ?? <StockMovement>[])]
      ..sort((a, b) {
        final wa = a.when, wb = b.when;
        if (wa == null || wb == null) return 0;
        return wb.compareTo(wa); // newest first
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              _buildMonthHeader(today),
              const SizedBox(height: 10),
              Row(
                children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
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
                  childAspectRatio: 0.88,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox.shrink();

                  final day = index - leadingBlanks + 1;
                  final date =
                      DateTime(_visibleMonth.year, _visibleMonth.month, day);
                  final moves = byDay[date] ?? const <StockMovement>[];
                  final hasIn = moves.any((m) => m.isIn);
                  final hasOut = moves.any((m) => !m.isIn);
                  final isSelected = date == _dayOnly(_selectedDay);
                  final isToday = date == today;
                  final isHot =
                      moves.isNotEmpty && busiest > 0 && moves.length >= busiest * 0.6;

                  Color? bg;
                  Color fg = AppColors.textPrimary;
                  if (isSelected) {
                    bg = AppColors.dark;
                    fg = Colors.white;
                  } else if (moves.isNotEmpty) {
                    bg = isHot ? AppColors.primary : AppColors.successSoft;
                    fg = isHot ? const Color(0xFF06170C) : AppColors.primaryDeep;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(2),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDay = date),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(12),
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.dark, width: 1.4)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 3),
                            SizedBox(
                              height: 5,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasIn) _dot(AppColors.primaryDeep, isSelected),
                                  if (hasIn && hasOut) const SizedBox(width: 2),
                                  if (hasOut) _dot(AppColors.error, isSelected),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _legend(AppColors.primaryDeep, 'Received'),
                  const SizedBox(width: 12),
                  _legend(AppColors.error, 'Dispensed'),
                  const Spacer(),
                  Text(
                    '$monthMoves moves · +$monthIn / −$monthOut',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildDayDetail(selectedMoves),
      ],
    );
  }

  Widget _dot(Color color, bool onDark) => Container(
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          color: onDark ? Colors.white : color,
          shape: BoxShape.circle,
        ),
      );

  Widget _legend(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      );

  Widget _buildMonthHeader(DateTime today) {
    Widget arrow(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 19),
          ),
        );

    final isThisMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    return Row(
      children: [
        arrow(
          Icons.chevron_left_rounded,
          () => setState(() => _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDay,
                firstDate: DateTime(2020),
                lastDate: DateTime(today.year + 1, 12, 31),
              );
              if (picked != null) {
                setState(() {
                  _selectedDay = _dayOnly(picked);
                  _visibleMonth = DateTime(picked.year, picked.month);
                });
              }
            },
            child: Center(
              child: Text(
                DateFormat('MMMM y').format(_visibleMonth),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
          ),
        ),
        if (!isThisMonth)
          GestureDetector(
            onTap: () => setState(() {
              _visibleMonth = DateTime(today.year, today.month);
              _selectedDay = today;
            }),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Today',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
              ),
            ),
          ),
        arrow(
          Icons.chevron_right_rounded,
          () => setState(() => _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // Day detail
  // --------------------------------------------------------------------

  Widget _buildDayDetail(List<StockMovement> moves) {
    var inQty = 0, outQty = 0;
    // medicineId -> [in, out]
    final perMedicine = <int, List<int>>{};

    for (final m in moves) {
      final entry = perMedicine.putIfAbsent(m.medicineId, () => [0, 0]);
      if (m.isIn) {
        inQty += m.quantity;
        entry[0] += m.quantity;
      } else {
        outQty += m.quantity;
        entry[1] += m.quantity;
      }
    }

    final net = inQty - outQty;
    final timeFmt = DateFormat('HH:mm');

    return Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(_selectedDay),
                      style: AppTextStyles.bodySmall,
                    ),
                    Text(
                      DateFormat('d MMMM y').format(_selectedDay),
                      style: AppTextStyles.headingMedium,
                    ),
                  ],
                ),
              ),
              if (widget.onPrintDay != null)
                OutlinedButton.icon(
                  onPressed: moves.isEmpty
                      ? null
                      : () => widget.onPrintDay!(_selectedDay, moves),
                  icon: const Icon(Icons.print_outlined, size: 17),
                  label: const Text('Print'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statTile('Received', '+$inQty', AppColors.successSoft,
                  AppColors.primaryDeep),
              const SizedBox(width: 8),
              _statTile(
                  'Dispensed', '−$outQty', AppColors.errorSoft, AppColors.error),
              const SizedBox(width: 8),
              _statTile(
                'Net',
                '${net >= 0 ? '+' : '−'}${net.abs()}',
                AppColors.background,
                AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              _statTile('Moves', '${moves.length}', AppColors.background,
                  AppColors.textPrimary),
            ],
          ),
          if (moves.isEmpty) ...[
            const SizedBox(height: 18),
            Center(
              child: Column(
                children: [
                  Icon(Icons.event_available_outlined,
                      color: AppColors.textSecondary, size: 30),
                  const SizedBox(height: 6),
                  Text('Nothing happened on this day.',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ] else ...[
            const SizedBox(height: 18),
            Text('Medicines touched (${perMedicine.length})',
                style: AppTextStyles.headingSmall),
            const SizedBox(height: 8),
            ...perMedicine.entries.map((e) {
              final med = _medicine(e.key);
              final name = med?.name ??
                  moves.firstWhere((m) => m.medicineId == e.key).medicineName;
              final inQ = e.value[0], outQ = e.value[1];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    MedicineImage(url: med?.imageUrl, size: 36, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'Medicine #${e.key}' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (inQ > 0)
                      _qtyChip('+$inQ', AppColors.successSoft,
                          AppColors.primaryDeep),
                    if (inQ > 0 && outQ > 0) const SizedBox(width: 4),
                    if (outQ > 0)
                      _qtyChip('−$outQ', AppColors.errorSoft, AppColors.error),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            Text('Timeline', style: AppTextStyles.headingSmall),
            const SizedBox(height: 10),
            ...List.generate(moves.length, (i) {
              final m = moves[i];
              final isLast = i == moves.length - 1;
              final color = m.isIn ? AppColors.primaryDeep : AppColors.error;
              final when = m.when;

              final details = <String>[
                if (m.batchNumber.isNotEmpty) 'Batch ${m.batchNumber}',
                'by ${m.who}${m.performedByRole.isEmpty ? '' : ' (${m.performedByRole.split('_').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ')})'}',
                if (m.reference.isNotEmpty) m.reference,
              ].join('  ·  ');

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMovementDetails(context, m),
                child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          when == null ? '--:--' : timeFmt.format(when),
                          style: AppTextStyles.bodySmall
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: m.isIn
                                ? AppColors.successSoft
                                : AppColors.errorSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            m.isIn
                                ? Icons.south_west_rounded
                                : Icons.north_east_rounded,
                            size: 13,
                            color: color,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(width: 2, color: AppColors.border),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _name(m),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium
                                        .copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Text(
                                  '${m.isIn ? '+' : '−'}${m.quantity}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              m.label,
                              style: AppTextStyles.bodySmall.copyWith(color: color),
                            ),
                            if (details.isNotEmpty)
                              Text(details, style: AppTextStyles.bodySmall),
                            if (m.note.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '“${m.note}”',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: fg),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _qtyChip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: fg),
        ),
      );
}
