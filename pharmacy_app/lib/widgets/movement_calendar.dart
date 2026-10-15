import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_colors.dart';
import '../config/app_text_styles.dart';
import '../models/medicine.dart';
import '../models/stock_movement.dart';
import '../models/user.dart';
import 'medicine_image.dart';
import 'movement_details.dart';

/// Month calendar of stock movements plus a clean "what happened on this
/// day" panel: totals, a bar per medicine and a time-ordered timeline.
/// Everything is computed client-side from the movements list.
class MovementCalendar extends StatefulWidget {
  final List<StockMovement> movements;
  final List<Medicine> medicines;

  /// "Download PDF" for the selected day.
  final void Function(DateTime day)? onDownloadDay;

  /// "Print" for the selected day.
  final void Function(DateTime day, List<StockMovement> moves)? onPrintDay;

  const MovementCalendar({
    super.key,
    required this.movements,
    required this.medicines,
    this.onDownloadDay,
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

    final selectedMoves = [
      ...(byDay[_dayOnly(_selectedDay)] ?? <StockMovement>[])
    ]..sort((a, b) {
        final wa = a.when, wb = b.when;
        if (wa == null || wb == null) return 0;
        return wb.compareTo(wa); // newest first
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _buildMonthHeader(today),
              const SizedBox(height: 12),
              Row(
                children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 11,
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
                  childAspectRatio: 1,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox.shrink();

                  final day = index - leadingBlanks + 1;
                  final date =
                      DateTime(_visibleMonth.year, _visibleMonth.month, day);
                  final moves = byDay[date] ?? const <StockMovement>[];
                  final isSelected = date == _dayOnly(_selectedDay);
                  final isToday = date == today;
                  final isHot = moves.isNotEmpty &&
                      busiest > 0 &&
                      moves.length >= busiest * 0.6;
                  final isFuture = date.isAfter(today);

                  Color? bg;
                  Color fg = isFuture
                      ? AppColors.textSecondary.withValues(alpha: 0.6)
                      : AppColors.textPrimary;
                  if (isSelected) {
                    bg = AppColors.dark;
                    fg = Colors.white;
                  } else if (moves.isNotEmpty) {
                    bg = isHot ? AppColors.primary : AppColors.successSoft;
                    fg = isHot
                        ? const Color(0xFF06170C)
                        : AppColors.primaryDeep;
                  }

                  return Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedDay = date),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(color: AppColors.dark, width: 1.4)
                              : null,
                        ),
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _legend(AppColors.primary, 'Busy'),
                    const SizedBox(width: 12),
                    _legend(
                      AppColors.successSoft,
                      'Some activity',
                      border: AppColors.primaryDeep,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '$monthMoves moves · +$monthIn / -$monthOut',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildDayDetail(selectedMoves),
      ],
    );
  }

  Widget _legend(Color color, String label, {Color? border}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: border == null ? null : Border.all(color: border),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      );

  Widget _buildMonthHeader(DateTime today) {
    Widget arrow(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
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
          child: Center(
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
              child: Container(
                padding:
                    const EdgeInsets.only(left: 16, right: 6, top: 6, bottom: 6),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM y').format(_visibleMonth),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.expand_more_rounded, size: 18),
                    ),
                  ],
                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  color: Colors.white,
                ),
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
  // Day detail (matches the "11 July · 14 moves · IN / OUT" design)
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

    final ordered = perMedicine.entries.toList()
      ..sort((a, b) => (b.value[0] + b.value[1]).compareTo(a.value[0] + a.value[1]));

    var peak = 1;
    for (final e in ordered) {
      final t = e.value[0] + e.value[1];
      if (t > peak) peak = t;
    }

    final net = inQty - outQty;
    final timeFmt = DateFormat('HH:mm');
    final hasActions = widget.onDownloadDay != null || widget.onPrintDay != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- title row: weekday, big date, "N moves" pill, PDF menu ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(_selectedDay),
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          DateFormat('d MMMM').format(_selectedDay),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successSoft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '${moves.length} ${moves.length == 1 ? 'move' : 'moves'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasActions) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Day report',
                  enabled: moves.isNotEmpty,
                  onSelected: (value) {
                    if (value == 'pdf') {
                      widget.onDownloadDay?.call(_selectedDay);
                    } else {
                      widget.onPrintDay?.call(_selectedDay, moves);
                    }
                  },
                  itemBuilder: (_) => [
                    if (widget.onDownloadDay != null)
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Text('Download PDF'),
                      ),
                    if (widget.onPrintDay != null)
                      const PopupMenuItem(
                        value: 'print',
                        child: Text('Print'),
                      ),
                  ],
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.background,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: moves.isEmpty
                          ? AppColors.border
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 14),

          // ---- IN / OUT / NET ----
          Row(
            children: [
              _statTile('IN', '+$inQty', AppColors.successSoft,
                  AppColors.primaryDeep),
              const SizedBox(width: 8),
              _statTile('OUT', '-$outQty', AppColors.errorSoft, AppColors.error),
              const SizedBox(width: 8),
              _statTile(
                'NET',
                '${net > 0 ? '+' : (net < 0 ? '-' : '')}${net.abs()}',
                AppColors.background,
                AppColors.textPrimary,
              ),
            ],
          ),

          if (moves.isEmpty) ...[
            const SizedBox(height: 22),
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
            const SizedBox(height: 22),
            _sectionLabel('MEDICINES MOVED (${ordered.length})'),
            const SizedBox(height: 10),
            ...ordered.map((e) {
              final med = _medicine(e.key);
              final name = med?.name ??
                  moves.firstWhere((m) => m.medicineId == e.key).medicineName;
              final inQ = e.value[0], outQ = e.value[1];
              final total = inQ + outQ;

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        MedicineImage(url: med?.imageUrl, size: 32, radius: 9),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Medicine #${e.key}' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (inQ > 0)
                          Text(
                            '+$inQ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        if (inQ > 0 && outQ > 0) const SizedBox(width: 8),
                        if (outQ > 0)
                          Text(
                            '-$outQ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.error,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: SizedBox(
                        height: 7,
                        child: Row(
                          children: [
                            if (inQ > 0)
                              Expanded(
                                flex: (inQ * 1000 ~/ peak).clamp(1, 1000).toInt(),
                                child: Container(color: AppColors.primary),
                              ),
                            if (outQ > 0)
                              Expanded(
                                flex: (outQ * 1000 ~/ peak).clamp(1, 1000).toInt(),
                                child: Container(color: AppColors.error),
                              ),
                            Expanded(
                              flex: (1000 - (total * 1000 ~/ peak))
                                      .clamp(0, 1000)
                                      .toInt() +
                                  1,
                              child: Container(color: AppColors.border),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            _sectionLabel('TIMELINE'),
            const SizedBox(height: 12),
            ...List.generate(moves.length, (i) {
              final m = moves[i];
              final isLast = i == moves.length - 1;
              final color = m.isIn ? AppColors.primaryDeep : AppColors.error;
              final when = m.when;

              final details = <String>[
                if (m.batchNumber.isNotEmpty) 'Batch ${m.batchNumber}',
                'by ${m.who}'
                    '${m.performedByRole.isEmpty ? '' : ' (${User.prettyRoleName(m.performedByRole)})'}',
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
                              child:
                                  Container(width: 2, color: AppColors.border),
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
                                      style: AppTextStyles.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Text(
                                    '${m.isIn ? '+' : '-'}${m.quantity}',
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
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: color),
                              ),
                              if (details.isNotEmpty)
                                Text(details, style: AppTextStyles.bodySmall),
                              if (m.note.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '"${m.note}"',
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

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      );

  Widget _statTile(String label, String value, Color bg, Color fg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
