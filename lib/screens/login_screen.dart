import 'package:flutter/material.dart';
import 'package:lojistik/services/auth_service.dart';
import 'dart:math' as math;

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

    // 🔥 AuthService ile giriş yap
    final result = await AuthService.login(
      email: email,
      password: password,
    );

    setState(() => isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      final role = result['role'];
      final uid = result['uid'];

      // Role'e göre yönlendir
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
    final primaryColor = Colors.blueGrey.shade900;

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
                  // ----------------------------
                  // DESKTOP SOL TARAF
                  // ----------------------------
                  if (isDesktop)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 40),
                        child: Column(
                          children: [
                            Transform.rotate(
                              angle: -math.pi / 12,
                              child: const Icon(
                                Icons.local_shipping_rounded,
                                color: Colors.white,
                                size: 120,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              "Truck Management System",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Kurumsal Araç Takip ve İş Yönetimi",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ----------------------------
                  // GİRİŞ KARTI
                  // ----------------------------
                  Expanded(
                    flex: isDesktop ? 1 : 2,
                    child: Card(
                      color: Colors.white,
                      elevation: 16,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 38),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isDesktop) ...[
                              Transform.rotate(
                                angle: -math.pi / 12,
                                child: Icon(
                                  Icons.local_shipping_rounded,
                                  color: primaryColor,
                                  size: 80,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Truck Management System",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // EMAIL
                            TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: "E-posta",
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // PASSWORD
                            TextField(
                              controller: passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: "Şifre",
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible =
                                      !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 30),

                            // LOGIN BUTONU
                            isLoading
                                ? RotationTransition(
                              turns: Tween(begin: 0.0, end: 1.0)
                                  .animate(_animationController),
                              child: Icon(Icons.local_shipping_rounded,
                                  size: 55, color: primaryColor),
                            )
                                : SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  "Giriş Yap",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            if (errorMessage != null)
                              Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ),
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