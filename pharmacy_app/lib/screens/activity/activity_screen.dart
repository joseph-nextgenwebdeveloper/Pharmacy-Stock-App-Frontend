import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../models/activity_log.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/activity_tile.dart';
import '../../widgets/user_avatar.dart';

/// "Who did what". Everyone sees their own activity; administrators and
/// store managers can switch to the whole team and filter by person.
class ActivityScreen extends StatefulWidget {
  final bool team;

  const ActivityScreen({super.key, this.team = false});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  static const _types = <String, String?>{
    'All': null,
    'Stock in': 'STOCK_IN',
    'Stock out': 'STOCK_OUT',
    'Medicines': 'MEDICINE_CREATED,MEDICINE_UPDATED,MEDICINE_DELETED',
    'Batches': 'BATCH_CREATED,BATCH_UPDATED,BATCH_DELETED',
    'Sign-ins': 'LOGIN,LOGOUT',
  };

  List<ActivityLog> _items = [];
  List<StaffMember> _staff = [];
  bool _loading = true;
  String? _error;

  String _typeLabel = 'All';
  int? _userId;
  DateTime? _date;

  bool get _team => widget.team;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final filtered = _typeLabel != 'All' || _date != null;

    try {
      if (_team && _staff.isEmpty) {
        try {
          _staff = await ActivityService.getStaff();
        } catch (_) {}
      }

      _items = await ActivityService.getActivity(
        scope: _team ? 'all' : 'mine',
        userId: _team ? _userId : null,
        action: _types[_typeLabel],
        date: _date == null ? null : DateFormat('yyyy-MM-dd').format(_date!),
        hideSessions: _typeLabel == 'All',
      );
    } catch (e) {
      _error = e.toString();
      if (_items.isEmpty && !filtered) {
        _items = await ActivityService.getCached(
          scope: _team ? 'all' : 'mine',
          userId: _team ? _userId : null,
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) {
      _date = picked;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().user;
    final allowed = me?.canViewTeamActivity ?? false;

    if (_team && !allowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Team activity')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'Only administrators and store managers can see what the whole team has done.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: Text(_team ? 'Team activity' : 'My activity'),
        actions: [
          IconButton(
            tooltip: 'Pick a day',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_team && _staff.isNotEmpty) _staffChips(),
          _typeChips(),
          if (_date != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                children: [
                  Chip(
                    label: Text(DateFormat('EEE d MMM y').format(_date!)),
                    onDeleted: () {
                      _date = null;
                      _load();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Text(
                _error ?? 'No activity found.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ),
        ],
      );
    }

    // group by day
    final children = <Widget>[];
    String? lastDay;
    for (final log in _items) {
      final when = log.when;
      final dayKey = when == null ? '' : DateFormat('yyyy-MM-dd').format(when);
      if (dayKey != lastDay) {
        lastDay = dayKey;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Text(
              when == null ? '' : _dayHeading(when),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        );
      }
      children.add(ActivityTile(log: log, showUser: _team));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Showing saved activity. $_error',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ...children,
      ],
    );
  }

  String _dayHeading(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'TODAY';
    if (day == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return DateFormat('EEE d MMM y').format(d).toUpperCase();
  }

  Widget _typeChips() {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        children: _types.keys.map((label) {
          final selected = _typeLabel == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              showCheckmark: false,
              selectedColor: AppColors.dark,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              onSelected: (_) {
                _typeLabel = label;
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _staffChips() {
    Widget chip({required String label, String? url, required bool selected, required VoidCallback onTap}) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            ),
            child: Row(
              children: [
                UserAvatar(
                  url: url,
                  initials: label.isEmpty ? '?' : label[0].toUpperCase(),
                  radius: 12,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF06170C) : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
        children: [
          chip(
            label: 'Everyone',
            selected: _userId == null,
            onTap: () {
              _userId = null;
              _load();
            },
          ),
          ..._staff.map(
            (s) => chip(
              label: s.name,
              url: s.avatar,
              selected: _userId == s.id,
              onTap: () {
                _userId = s.id;
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }
}
