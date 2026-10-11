import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/notification_provider.dart';
import '../../routes/route_names.dart';
import '../../services/local_notification_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/offline_banner.dart';

class MainScreen extends StatefulWidget {
  final Widget child;

  const MainScreen({
    super.key,
    required this.child,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _refreshTimer;

  static const List<String> _routes = [
    RouteNames.dashboard,
    RouteNames.inventory,
    RouteNames.scanner,
    RouteNames.alerts,
    RouteNames.profile,
  ];

  /// While the app is open, re-check stock every few minutes so out-of-stock
  /// phone notifications (and their 2-hour reminders) follow real stock.
  static const Duration _refreshEvery = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Tapping a stock notification opens the Alerts tab.
    LocalNotificationService.onTap = (payload) {
      if (mounted) context.go(RouteNames.alerts);
    };

    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _syncStock());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncStock());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LocalNotificationService.onTap = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncStock();
  }

  Future<void> _syncStock() async {
    if (!mounted) return;
    if (!context.read<AuthProvider>().isAuthenticated) return;

    // loadMedicines also re-evaluates the out-of-stock phone reminders.
    await context.read<InventoryProvider>().loadMedicines();
    if (!mounted) return;
    await context.read<NotificationProvider>().loadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final location = GoRouterState.of(context).uri.path;

    final index = _routes.indexWhere(
      (route) => location.startsWith(route),
    );

    if (index != -1 && index != _currentIndex) {
      _currentIndex = index;
    }
  }

  void _onNavigationTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final offline = !context.watch<ConnectivityProvider>().isOnline;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            // The banner already covers the status bar, so the screen below
            // must not add that top padding a second time.
            child: offline
                ? MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.child,
                  )
                : widget.child,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationTap,
      ),
    );
  }
}
