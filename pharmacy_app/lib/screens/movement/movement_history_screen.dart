import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_text_styles.dart';
import '../../helpers/print_helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/movement_calendar.dart';

/// Full-screen movement calendar: pick any day to see everything that
/// happened on it, and print that day's activity.
class MovementHistoryScreen extends StatefulWidget {
  const MovementHistoryScreen({super.key});

  @override
  State<MovementHistoryScreen> createState() => _MovementHistoryScreenState();
}

class _MovementHistoryScreenState extends State<MovementHistoryScreen> {
  bool _onlyMine = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StockMovementProvider>().loadMovements();
      context.read<InventoryProvider>().loadMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Movement History', style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<StockMovementProvider>().refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Consumer2<StockMovementProvider, InventoryProvider>(
        builder: (context, provider, inventory, child) {
          if (provider.isLoading && provider.movements.isEmpty) {
            return const LoadingWidget();
          }

          if (provider.error != null && provider.movements.isEmpty) {
            return AppErrorWidget(
              message: provider.error!,
              onRetry: provider.loadMovements,
            );
          }

          final me = context.watch<AuthProvider>().user;
          final shown = _onlyMine && me != null
              ? provider.movements
                  .where((m) => m.performedById == me.id)
                  .toList()
              : provider.movements;

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Everyone'),
                      selected: !_onlyMine,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _onlyMine = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Only me'),
                      selected: _onlyMine,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _onlyMine = true),
                    ),
                    const Spacer(),
                    Text(
                      'Tap a movement for full details',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MovementCalendar(
                  movements: shown,
                  medicines: inventory.medicines,
                  onPrintDay: (day, moves) =>
                      printDayReport(context, day, moves),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
