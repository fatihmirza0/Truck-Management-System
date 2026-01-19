import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lojistik/services/auth_service.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/floating_particles.dart';
import 'package:lojistik/screens/developer/developer_login_page.dart';

import '../widgets/login_desktop_panel.dart';
import '../widgets/login_form_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => errorMessage = "Geçerli bir e-posta girin");
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => errorMessage = "Şifre en az 6 karakter olmalı");
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    await AuthService.logoutFast();

    final result = await AuthService.login(
      email: email,
      password: password,
    );

    setState(() => isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      final role = result['role'];

      if (role == 'manager') {
        context.go('/manager');
      } else if (role == 'dispatch') {
        context.go('/dispatch');
      } else if (role == 'driver') {
        context.go('/driver');
      } else {
        setState(() => errorMessage = "Bilinmeyen kullanıcı tipi");
      }
    } else {
      setState(() => errorMessage = result['message'] ?? 'Giriş başarısız');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: AppTheme.gradientBackground,
          ),

          // Floating particles
          const Positioned.fill(
            child: FloatingParticles(
              particleCount: 40,
              color: Colors.white,
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : 20,
                vertical: isDesktop ? 40 : 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 950),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isDesktop) 
                           LoginDesktopPanel(
                             withAnimation: true,
                             onSecretTap: _handleSecretTap,
                           ),
                        LoginFormCard(
                          emailController: emailController,
                          passwordController: passwordController,
                          isPasswordVisible: _isPasswordVisible,
                          withAnimation: true,
                          onTogglePassword: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                          onLogin: login,
                          isLoading: isLoading,
                          errorMessage: errorMessage,
                          onSecretTap: _handleSecretTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Secret Entry Logic
  int _secretTapCount = 0;
  DateTime? _lastTapTime;

  void _handleSecretTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) > const Duration(seconds: 1)) {
       _secretTapCount = 0; // Reset if too slow
    }
    
    _lastTapTime = now;
    _secretTapCount++;

    if (_secretTapCount >= 7) {
      _secretTapCount = 0;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DeveloperLoginPage(),
        ),
      );
    }
  }

}