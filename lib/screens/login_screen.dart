import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailController.text.trim())
          .where('password', isEqualTo: passwordController.text.trim())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          errorMessage = "Geçersiz e-posta veya şifre";
          isLoading = false;
        });
        return;
      }

      final userData = query.docs.first.data();
      final roleId = userData['roleId'];

      if (roleId == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager');
      } else if (roleId == 'dispatch') {
        Navigator.pushReplacementNamed(context, '/dispatch');
      } else if (roleId == 'driver') {
        final driverId = userData['driverId'];
        Navigator.pushReplacementNamed(
          context,
          '/driver',
          arguments: {'driverId': driverId ?? ''},
        );
      } else {
        setState(() => errorMessage = "Bilinmeyen kullanıcı tipi");
      }
    } catch (e) {
      setState(() => errorMessage = "Hata: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.blueGrey.shade800;
    final secondaryColor = Colors.blueGrey.shade400;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade600],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔹 Logo + Başlık
                Transform.rotate(
                  angle: -math.pi / 12,
                  child: Icon(
                    Icons.local_shipping_rounded,
                    color: Colors.white,
                    size: 90,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Truck Management System",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Kurumsal Araç Takip ve Görev Yönetimi",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 50),

                // 🔹 Giriş Kartı
                Card(
                  color: Colors.white,
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "E-posta",
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: "Şifre",
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey[700],
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 🔹 Buton veya animasyon
                        isLoading
                            ? RotationTransition(
                          turns: Tween(begin: 0.0, end: 1.0)
                              .animate(_animationController),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            size: 50,
                            color: secondaryColor,
                          ),
                        )
                            : SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Giriş Yap",
                              style: TextStyle(
                                  fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (errorMessage != null)
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                Text(
                  "© 2025 Truck Management System",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
