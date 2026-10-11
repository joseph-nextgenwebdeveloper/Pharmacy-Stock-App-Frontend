import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_sizes.dart';
import '../../config/app_text_styles.dart';
import '../../models/expired_medicine_report.dart';
import '../../models/fast_moving_medicine.dart';
import '../../models/inventory_report.dart';
import '../../models/monthly_movement_report.dart';
import '../../models/slow_moving_medicine.dart';
import '../../models/stock_valuation_report.dart';
import '../../helpers/print_helpers.dart';
import '../../models/batch.dart';
import '../../models/stock_movement.dart';
import '../../providers/batch_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/stock_movement_provider.dart';
import '../../services/report_printer.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() =>
      _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _selectedReport;
  DateTime _reportDay = DateTime.now();

  final int _currentYear = DateTime.now().year;
  final int _currentMonth = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reports',
          style: AppTextStyles.headingMedium,
        ),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (_selectedReport == null) {
            return _buildReportMenu(context);
          }

          return _buildSelectedReport(
            context,
            provider,
          );
        },
      ),
    );
  }

  Widget _buildReportMenu(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      children: [
        _ReportCard(
          title: 'Inventory Report',
          description:
              'View medicine stock and inventory information.',
          icon: Icons.inventory_2_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'inventory';
            });

            context
                .read<ReportProvider>()
                .loadInventoryReport();
          },
        ),
        _ReportCard(
          title: 'Stock Valuation',
          description:
              'View the current value of pharmacy stock.',
          icon:
              Icons.account_balance_wallet_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'valuation';
            });

            context
                .read<ReportProvider>()
                .loadStockValuationReport();
          },
        ),
        _ReportCard(
          title: 'Expired Medicines',
          description:
              'View medicines that have already expired.',
          icon: Icons.event_busy_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'expired';
            });

            context
                .read<ReportProvider>()
                .loadExpiredMedicineReport();
          },
        ),
        _ReportCard(
          title: 'Monthly Movement',
          description:
              'Review monthly stock movement activity.',
          icon: Icons.bar_chart_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'monthly';
            });

            context
                .read<ReportProvider>()
                .loadMonthlyMovementReport(
                  year: _currentYear,
                  month: _currentMonth,
                );
          },
        ),
        _ReportCard(
          title: 'Fast-Moving Medicines',
          description:
              'View medicines with higher sales activity.',
          icon: Icons.trending_up_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'fast';
            });

            context
                .read<ReportProvider>()
                .loadFastMovingMedicines();
          },
        ),
        _ReportCard(
          title: 'Slow-Moving Medicines',
          description:
              'View medicines with lower sales activity.',
          icon: Icons.trending_down_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'slow';
            });

            context
                .read<ReportProvider>()
                .loadSlowMovingMedicines();
          },
        ),
        _ReportCard(
          title: 'Batch Register',
          description:
              'Every batch with supplier, prices, quantities and expiry.',
          icon: Icons.inventory_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'batches';
            });

            context.read<BatchProvider>().loadBatches();
            context.read<InventoryProvider>().loadMedicines();
          },
        ),
        _ReportCard(
          title: 'Daily Activity',
          description:
              'Everything received and dispensed on a chosen day.',
          icon: Icons.today_outlined,
          onTap: () {
            setState(() {
              _selectedReport = 'daily';
              _reportDay = DateTime.now();
            });

            context.read<StockMovementProvider>().loadMovements();
            context.read<InventoryProvider>().loadMedicines();
          },
        ),
      ],
    );
  }

  Widget _buildSelectedReport(
    BuildContext context,
    ReportProvider provider,
  ) {
    if (provider.isLoading) {
      return const LoadingWidget();
    }

    if (provider.error != null) {
      return AppErrorWidget(
        message: provider.error!,
        onRetry: () {
          _reloadSelectedReport(provider);
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.paddingMedium,
            AppSizes.paddingMedium,
            AppSizes.paddingMedium,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedReport = null;
                  });
                },
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  _reportTitle(),
                  style: AppTextStyles.headingMedium,
                ),
              ),
              IconButton(
                tooltip: 'Print / save as PDF',
                onPressed: () => _printSelected(context, provider),
                icon: const Icon(Icons.print_outlined),
              ),
              IconButton(
                onPressed: () {
                  _reloadSelectedReport(provider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildReportContent(provider),
        ),
      ],
    );
  }

  Widget _buildReportContent(ReportProvider provider) {
    switch (_selectedReport) {
      case 'inventory':
        return _InventoryReportView(
          reports: provider.inventoryReport,
        );

      case 'valuation':
        return _StockValuationReportView(
          reports: provider.stockValuationReport,
        );

      case 'expired':
        return _ExpiredReportView(
          reports: provider.expiredMedicineReport,
        );

      case 'monthly':
        return _MonthlyMovementReportView(
          report: provider.monthlyMovementReport,
        );

      case 'fast':
        return _FastMovingReportView(
          reports: provider.fastMovingMedicines,
        );

      case 'slow':
        return _SlowMovingReportView(
          reports: provider.slowMovingMedicines,
        );

      case 'batches':
        return const _BatchRegisterView();

      case 'daily':
        return _DailyActivityView(
          day: _reportDay,
          onPickDay: (d) => setState(() => _reportDay = d),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _reportTitle() {
    switch (_selectedReport) {
      case 'inventory':
        return 'Inventory Report';
      case 'valuation':
        return 'Stock Valuation';
      case 'expired':
        return 'Expired Medicines';
      case 'monthly':
        return 'Monthly Movement';
      case 'fast':
        return 'Fast-Moving Medicines';
      case 'slow':
        return 'Slow-Moving Medicines';
      case 'batches':
        return 'Batch Register';
      case 'daily':
        return 'Daily Activity';
      default:
        return 'Reports';
    }
  }

  void _reloadSelectedReport(
    ReportProvider provider,
  ) {
    switch (_selectedReport) {
      case 'inventory':
        provider.loadInventoryReport();
        break;
      case 'valuation':
        provider.loadStockValuationReport();
        break;
      case 'expired':
        provider.loadExpiredMedicineReport();
        break;
      case 'monthly':
        provider.loadMonthlyMovementReport(
          year: _currentYear,
          month: _currentMonth,
        );
        break;
      case 'fast':
        provider.loadFastMovingMedicines();
        break;
      case 'slow':
        provider.loadSlowMovingMedicines();
        break;
      case 'batches':
        context.read<BatchProvider>().loadBatches();
        break;
      case 'daily':
        context.read<StockMovementProvider>().loadMovements();
        break;
    }
  }

  Future<void> _printSelected(
    BuildContext context,
    ReportProvider provider,
  ) async {
    final prepared = preparedByName(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      switch (_selectedReport) {
        case 'inventory':
          await ReportPrinter.inventory(provider.inventoryReport,
              preparedBy: prepared);
          break;
        case 'valuation':
          await ReportPrinter.valuation(provider.stockValuationReport,
              preparedBy: prepared);
          break;
        case 'expired':
          await ReportPrinter.expired(provider.expiredMedicineReport,
              preparedBy: prepared);
          break;
        case 'monthly':
          await ReportPrinter.monthly(provider.monthlyMovementReport,
              preparedBy: prepared);
          break;
        case 'fast':
          await ReportPrinter.fastMoving(provider.fastMovingMedicines,
              preparedBy: prepared);
          break;
        case 'slow':
          await ReportPrinter.slowMoving(provider.slowMovingMedicines,
              preparedBy: prepared);
          break;
        case 'batches':
          final medicines = context.read<InventoryProvider>().medicines;
          await ReportPrinter.batchRegister(
            context.read<BatchProvider>().batches,
            preparedBy: prepared,
            medicineName: (b) {
              if (b.medicineName.isNotEmpty) return b.medicineName;
              for (final m in medicines) {
                if (m.id == b.medicineId) return m.name;
              }
              return 'Medicine #${b.medicineId}';
            },
          );
          break;
        case 'daily':
          final all = context.read<StockMovementProvider>().movements;
          final day = DateTime(_reportDay.year, _reportDay.month, _reportDay.day);
          await printDayReport(
            context,
            day,
            all.where((m) => m.day == day).toList(),
          );
          break;
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open the print dialog: $e')),
      );
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: AppSizes.spacingSmall,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMedium,
          vertical: AppSizes.paddingSmall,
        ),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: AppTextStyles.headingSmall,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: AppTextStyles.bodySmall,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
      ),
    );
  }
}

class _InventoryReportView extends StatelessWidget {
  final List<InventoryReport> reports;

  const _InventoryReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No inventory report data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Reorder level: ${report.reorderLevel}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text('${report.quantity}'),
                const SizedBox(height: 4),
                Text(
                  report.status,
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StockValuationReportView extends StatelessWidget {
  final List<StockValuationReport> reports;

  const _StockValuationReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No stock valuation data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Quantity: ${report.quantity}',
            ),
            isThreeLine: true,
            trailing: Text(
              'KSh ${report.stockValue.toStringAsFixed(2)}',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExpiredReportView extends StatelessWidget {
  final List<ExpiredMedicineReport> reports;

  const _ExpiredReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message: 'No expired medicines found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}\n'
              'Batch: ${report.batchNumber}\n'
              'Expiry: ${report.expiryDate}',
            ),
            isThreeLine: true,
            trailing: Text(
              '${report.quantity}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _MonthlyMovementReportView
    extends StatelessWidget {
  final MonthlyMovementReport? report;

  const _MonthlyMovementReportView({
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const _EmptyReport(
        message: 'No monthly movement data found.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(
              AppSizes.paddingMedium,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${report!.year} - '
                  '${report!.month.toString().padLeft(2, '0')}',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                _MovementValue(
                  label: 'Stock Received',
                  value: report!.stockReceived,
                  icon: Icons.input_outlined,
                ),
                const SizedBox(
                  height: AppSizes.spacingMedium,
                ),
                _MovementValue(
                  label: 'Stock Dispensed',
                  value: report!.stockDispensed,
                  icon: Icons.output_outlined,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MovementValue extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _MovementValue({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        Text(
          '$value',
          style: AppTextStyles.headingSmall,
        ),
      ],
    );
  }
}

class _FastMovingReportView extends StatelessWidget {
  final List<FastMovingMedicine> reports;

  const _FastMovingReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message:
            'No fast-moving medicine data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}',
            ),
            trailing: Text(
              '${report.quantityDispensed}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _SlowMovingReportView extends StatelessWidget {
  final List<SlowMovingMedicine> reports;

  const _SlowMovingReportView({
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyReport(
        message:
            'No slow-moving medicine data found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(
        AppSizes.paddingMedium,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];

        return Card(
          child: ListTile(
            title: Text(
              report.medicine,
              style: AppTextStyles.headingSmall,
            ),
            subtitle: Text(
              'SKU: ${report.sku}',
            ),
            trailing: Text(
              '${report.quantityDispensed}',
              style: AppTextStyles.headingSmall,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(
          AppSizes.paddingLarge,
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}

/// On-screen preview of the Batch Register report.
class _BatchRegisterView extends StatelessWidget {
  const _BatchRegisterView();

  @override
  Widget build(BuildContext context) {
    return Consumer2<BatchProvider, InventoryProvider>(
      builder: (context, batchProvider, inventory, child) {
        if (batchProvider.isLoading && batchProvider.batches.isEmpty) {
          return const LoadingWidget();
        }

        final batches = [...batchProvider.batches]
          ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

        if (batches.isEmpty) {
          return const _EmptyReport(message: 'No batches recorded yet.');
        }

        String nameOf(Batch b) {
          if (b.medicineName.isNotEmpty) return b.medicineName;
          for (final m in inventory.medicines) {
            if (m.id == b.medicineId) return m.name;
          }
          return 'Medicine #${b.medicineId}';
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          itemCount: batches.length,
          itemBuilder: (context, i) {
            final b = batches[i];

            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
              child: ListTile(
                title: Text(nameOf(b), style: AppTextStyles.headingSmall),
                subtitle: Text(
                  'Batch ${b.batchNumber}  |  exp ${b.expiryDate}\n'
                  '${b.supplierName.isEmpty ? 'No supplier' : b.supplierName}  |  '
                  '${b.quantity}/${b.originalQuantity > 0 ? b.originalQuantity : b.quantity} left',
                  style: AppTextStyles.bodySmall,
                ),
                isThreeLine: true,
                trailing: Text(b.statusLabel, style: AppTextStyles.label),
              ),
            );
          },
        );
      },
    );
  }
}

/// On-screen preview of the Daily Activity report, with a day picker.
class _DailyActivityView extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onPickDay;

  const _DailyActivityView({required this.day, required this.onPickDay});

  @override
  Widget build(BuildContext context) {
    return Consumer2<StockMovementProvider, InventoryProvider>(
      builder: (context, provider, inventory, child) {
        final d = DateTime(day.year, day.month, day.day);
        final moves = provider.movements.where((m) => m.day == d).toList()
          ..sort((a, b) {
            final wa = a.when, wb = b.when;
            if (wa == null || wb == null) return 0;
            return wa.compareTo(wb);
          });

        String nameOf(StockMovement m) {
          if (m.medicineName.isNotEmpty) return m.medicineName;
          for (final med in inventory.medicines) {
            if (med.id == m.medicineId) return med.name;
          }
          return 'Medicine #${m.medicineId}';
        }

        final inQty =
            moves.where((m) => m.isIn).fold<int>(0, (s, m) => s + m.quantity);
        final outQty =
            moves.where((m) => !m.isIn).fold<int>(0, (s, m) => s + m.quantity);

        return ListView(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: d,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onPickDay(picked);
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat('EEEE, d MMMM y').format(d)),
            ),
            const SizedBox(height: 12),
            Text(
              '${moves.length} movements  |  received $inQty  |  dispensed $outQty',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 12),
            if (moves.isEmpty)
              const _EmptyReport(message: 'No movements on this day.')
            else
              ...moves.map(
                (m) => Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.spacingSmall),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(m.isIn
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded),
                    ),
                    title: Text(nameOf(m), style: AppTextStyles.headingSmall),
                    subtitle: Text(
                      '${m.when == null ? '' : DateFormat('HH:mm').format(m.when!)}'
                      '${m.batchNumber.isEmpty ? '' : '  |  batch ${m.batchNumber}'}'
                      '${m.performedByName.isEmpty ? '' : '  |  ${m.performedByName}'}',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: Text(
                      '${m.isIn ? '+' : '-'}${m.quantity}',
                      style: AppTextStyles.headingSmall,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
