import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lojistik/core/constants/app_routes.dart';
import 'package:lojistik/presentation/screens/common/splash/splash_screen.dart';
import 'package:lojistik/screens/login_screen.dart';
import 'package:lojistik/screens/manager/manager_screen.dart';
import 'package:lojistik/screens/dispatch/dispatch_main_screen.dart';
import 'package:lojistik/screens/driver/driver_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.manager,
        builder: (context, state) => const ManagerScreen(),
      ),
      GoRoute(
        path: AppRoutes.dispatch,
        builder: (context, state) {
          final uid = state.uri.queryParameters['uid'] ?? '';
          return DispatchMainScreen(uid: uid);
        },
      ),
      GoRoute(
        path: AppRoutes.driver,
        builder: (context, state) {
          final uid = state.uri.queryParameters['uid'] ?? '';
          return DriverScreen(uid: uid);
        },
      ),
    ],
  );
});
