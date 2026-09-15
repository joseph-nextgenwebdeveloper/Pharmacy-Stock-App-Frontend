import 'package:flutter/material.dart';

import 'routes/app_router.dart';
import 'services/api_service.dart';
import 'services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiService.initialize();
  await LocalNotificationService.initialize();

  await LocalNotificationService.scheduleDailyInventoryReminder(
    hour: 8,
    minute: 0,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'JoseKiarie Pharmacy',
      routerConfig: AppRouter.router,
    );
  }
}


