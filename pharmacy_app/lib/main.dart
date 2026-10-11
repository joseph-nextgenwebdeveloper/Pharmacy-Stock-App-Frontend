import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'providers/activity_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/batch_provider.dart';
import 'providers/category_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';
import 'services/api_service.dart';
import 'services/local_notification_service.dart';
import 'providers/report_provider.dart';
import 'providers/stock_movement_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initialize();

  // Load the saved light/dark choice before the first frame.
  final themeProvider = ThemeProvider();
  await themeProvider.load();

  // Local notifications are a nice-to-have — never let a failure here
  // (missing exact-alarm permission, a platform channel error, etc.) block
  // app startup. Previously this was unguarded and, when it threw on a
  // real device, the app never reached runApp() and stayed stuck on the
  // native launch screen forever.
  try {
    await LocalNotificationService.initialize();
    await LocalNotificationService.scheduleDailyInventoryReminder(
      hour: 8,
      minute: 0,
    );
  } catch (e, stack) {
    debugPrint('Local notification setup failed: $e\n$stack');
  }

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => StockMovementProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => InventoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => BatchProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PurchaseProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SalesProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SupplierProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'JoseKiarie Pharmacy',
          theme: AppTheme.current,
          themeMode: theme.mode,
          routerConfig: AppRouter.router,
          // Most colours are read straight from AppColors, so switching
          // light/dark re-keys the whole tree to repaint every screen.
          builder: (context, child) => KeyedSubtree(
            key: ValueKey(theme.isDark),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
