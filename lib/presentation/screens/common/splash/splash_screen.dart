import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lojistik/core/constants/app_routes.dart';
import 'package:lojistik/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 600), _check);
  }

  Future<void> _check() async {
    final authState = ref.read(authNotifierProvider);
    if (authState.isLoading) {
      await ref.read(authNotifierProvider.notifier).restoreSession();
    }
    final user = ref.read(authNotifierProvider).user;
    if (!mounted) return;
    if (user == null) {
      context.go(AppRoutes.login);
    } else {
      switch (user.role) {
        case 'manager':
          context.go(AppRoutes.manager);
          break;
        case 'dispatch':
          context.go('${AppRoutes.dispatch}?uid=${user.id}');
          break;
        case 'driver':
        default:
          context.go('${AppRoutes.driver}?uid=${user.id}');
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
