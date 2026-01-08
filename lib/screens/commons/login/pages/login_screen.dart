import 'package:flutter/material.dart';
import 'package:lojistik/services/auth_service.dart';

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

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
      final uid = result['uid'];

      if (role == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager');
      } else if (role == 'dispatch') {
        Navigator.pushReplacementNamed(
          context,
          '/dispatch',
          arguments: {"uid": uid},
        );
      } else if (role == 'driver') {
        Navigator.pushReplacementNamed(
          context,
          '/driver',
          arguments: {"uid": uid},
        );
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade900,
              Colors.blueGrey.shade700,
              Colors.blueGrey.shade600
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 20,
              vertical: isDesktop ? 40 : 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDesktop) const LoginDesktopPanel(),
                  LoginFormCard(
                    emailController: emailController,
                    passwordController: passwordController,
                    isPasswordVisible: _isPasswordVisible,
                    onTogglePassword: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    onLogin: login,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


