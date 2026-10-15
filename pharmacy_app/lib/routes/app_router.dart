import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/alerts/alerts_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/inventory/add_medicine_screen.dart';
import '../screens/inventory/batch_detail_screen.dart';
import '../screens/inventory/batches_screen.dart';
import '../screens/inventory/create_batch_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/medicine/medicine_detail_screen.dart';
import '../screens/movement/movement_history_screen.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/purchases/purchase_screen.dart';
import '../screens/reports/activity_report_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/sales/sales_screen.dart';
import '../screens/scanner/scanner_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/suppliers/supplier_screen.dart';
import '../services/auth_service.dart';
import 'route_names.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) async {
      final location = state.uri.path;

      final isSplash = location == RouteNames.splash;
      final isLogin = location == RouteNames.login;
      final isRegister = location == RouteNames.register;

      if (isSplash || isLogin || isRegister) {
        return null;
      }

      final isLoggedIn = await AuthService.isLoggedIn();

      if (!isLoggedIn) {
        return RouteNames.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) =>
            const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScreen(child: child);
        },
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            builder: (context, state) =>
                const DashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.inventory,
            builder: (context, state) =>
                const InventoryScreen(),
          ),
          GoRoute(
            path: RouteNames.addMedicine,
            builder: (context, state) => AddMedicineScreen(
              initialBarcode: state.uri.queryParameters['barcode'],
            ),
          ),
          GoRoute(
            path: RouteNames.batches,
            builder: (context, state) =>
                const BatchesScreen(),
          ),
          // Must stay above '/inventory/batches/:id' so "new" isn't read as an id.
          GoRoute(
            path: RouteNames.createBatch,
            builder: (context, state) {
              final q = state.uri.queryParameters;

              return CreateBatchScreen(
                initialMedicineId: int.tryParse(q['medicine'] ?? ''),
                initialBatchNumber: q['batch'],
                initialExpiry: DateTime.tryParse(q['expiry'] ?? ''),
              );
            },
          ),
          GoRoute(
            path: '${RouteNames.batches}/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');

              if (id == null) {
                return const Scaffold(
                  body: Center(child: Text('Invalid batch ID.')),
                );
              }

              return BatchDetailScreen(batchId: id);
            },
          ),
          GoRoute(
            path: '${RouteNames.medicine}/:id',
            builder: (context, state) {
              final id = int.tryParse(
                state.pathParameters['id'] ?? '',
              );

              if (id == null) {
                return const Scaffold(
                  body: Center(
                    child: Text(
                      'Invalid medicine ID.',
                    ),
                  ),
                );
              }

              return MedicineDetailScreen(
                medicineId: id,
              );
            },
          ),
          GoRoute(
            path: RouteNames.purchases,
            builder: (context, state) =>
                const PurchaseScreen(),
          ),
          GoRoute(
            path: RouteNames.sales,
            builder: (context, state) =>
                const SalesScreen(),
          ),
          GoRoute(
            path: RouteNames.suppliers,
            builder: (context, state) =>
                const SupplierScreen(),
          ),
          GoRoute(
            path: RouteNames.reports,
            builder: (context, state) =>
                const ReportsScreen(),
          ),
          GoRoute(
            path: RouteNames.activityReport,
            builder: (context, state) => ActivityReportScreen(
              initialPeriod:
                  state.uri.queryParameters['period'] ?? 'week',
            ),
          ),
          GoRoute(
            path: RouteNames.scanner,
            builder: (context, state) => ScannerScreen(
              pickMode: state.uri.queryParameters['pick'] == '1',
            ),
          ),
          GoRoute(
            path: RouteNames.alerts,
            builder: (context, state) =>
                const AlertsScreen(),
          ),
          GoRoute(
            path: RouteNames.activity,
            builder: (context, state) => ActivityScreen(
              team: state.uri.queryParameters['team'] == '1',
            ),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (context, state) =>
                const ProfileScreen(),
          ),
          GoRoute(
            path: RouteNames.movementHistory,
            builder: (context, state) =>
                const MovementHistoryScreen(),
          ),
        ],
      ),
    ],
  );
}