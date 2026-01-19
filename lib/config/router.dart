import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/commons/login/pages/login_screen.dart';
import '../services/auth_service.dart';

// Feature Screens
import '../screens/manager/manager_screen.dart';
import '../screens/dispatch/dispatch_main_screen.dart';
import '../screens/driver/driver_screen.dart';
import '../screens/commons/live_tracking_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn = await AuthService.isLoggedIn();
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) return isLoggingIn ? null : '/login';
      
      if (isLoggingIn) {
        final role = await AuthService.getSavedUserRole();
        if (role == 'manager') return '/manager';
        if (role == 'dispatch') return '/dispatch';
        if (role == 'driver') return '/driver';
        return '/manager';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Manager Routes (Legacy)
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerScreen(),
      ),

      // Dispatcher Routes (Legacy)
      GoRoute(
        path: '/dispatch',
        builder: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          return DispatchMainScreen(uid: user?.uid ?? '');
        }
      ),

      // Driver Routes (Legacy)
      GoRoute(
        path: '/driver',
        builder: (context, state) {
          final user = FirebaseAuth.instance.currentUser;
          return DriverScreen(uid: user?.uid ?? '');
        },
      ),

      // Common Routes
      GoRoute(
        path: '/live-tracking',
        builder: (context, state) => const LiveTrackingPanel(),
      ),
    ],
  );
}
