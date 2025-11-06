import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'managerScreens/manager_screen.dart';
import 'dispatchScreens/dispatch_main_screen.dart';
import 'driver_screen.dart';
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
    _animationController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ManagerScreen()),
        );
      } else if (roleId == 'dispatch') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DispatchMainScreen()),
        );
      } else if (roleId == 'driver') {
        final driverId = userData['driverId'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => DriverScreen(driverId: driverId ?? '')),
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
    final primaryColor = Colors.blueGrey[800];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔹 Başlık
              Text(
                "Truck Management System",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Kurumsal Araç Takip ve Görev Yönetimi",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 50),

              // 🔹 Giriş Kartı
              Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
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
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
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

                      // 🔹 Buton veya Yükleniyor Animasyonu
                      isLoading
                          ? RotationTransition(
                        turns: Tween(begin: 0.0, end: 1.0)
                            .animate(_animationController),
                        child: Icon(
                          Icons.local_shipping,
                          size: 50,
                          color: primaryColor,
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

                      // 🔹 Hata mesajı
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 50),

              // 🔹 Footer
              Text(
                "© 2025 Truck Management System",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
