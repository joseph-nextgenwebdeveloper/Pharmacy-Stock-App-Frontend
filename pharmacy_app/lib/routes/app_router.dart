import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}