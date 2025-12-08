import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import '../widgets/app_theme.dart';

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

    // 1️⃣ Ön validasyon
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

    try {
      // 2️⃣ Firebase Auth ile giriş
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user!.uid;

      // 3️⃣ Firestore’dan kullanıcı verilerini çek
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        setState(() => errorMessage = "Kullanıcı verisi bulunamadı");
        return;
      }

      final data = userDoc.data()!;
      final roleId = data['roleId'] ?? '';
      final driverId = data['driverId'] ?? '';

      // 4️⃣ Kullanıcı rolüne göre yönlendirme
      if (roleId == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager');
      } else if (roleId == 'dispatch') {
        Navigator.pushReplacementNamed(context, '/dispatch');
      } else if (roleId == 'driver') {
        Navigator.pushReplacementNamed(context, '/driver', arguments: {
          'driverId': driverId,
        });
      } else {
        setState(() => errorMessage = "Bilinmeyen kullanıcı tipi");
      }
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          setState(() => errorMessage = "Kayıtlı olmayan e-posta");
          break;
        case 'invalid-credential':
          setState(() => errorMessage = "Geçersiz e-posta veya şifre");
          break;
        case 'invalid-email':
          setState(() => errorMessage = "Geçersiz e-posta formatı");
          break;
        default:
          setState(() => errorMessage = "Hata: ${e.message}");
      }
    } catch (e) {
      // Diğer beklenmedik hatalar
      setState(() => errorMessage = "Beklenmeyen hata: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;
    final primaryColor = AppTheme.primary;
    final gradientColors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.primary.withOpacity(0.85),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
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
                  if (isDesktop)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 40),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Transform.rotate(
                                angle: -math.pi / 12,
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: Colors.white,
                                  size: 115,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Truck Management System",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Kurumsal Araç Takip ve Görev Yönetimi",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(18),
                                border:
                                    Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    " • Gerçek zamanlı filo görünürlüğü",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    " • Güvenli görev atama ve takip",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    " • İleri seviye raporlama ve içgörü",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Giriş yapın",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(color: primaryColor),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Kurumsal hesabınızla giriş yaparak araç, sürücü ve operasyonlarınızı yönetin.",
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
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
                                  onPressed: () => setState(() =>
                                      _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            isLoading
                                ? RotationTransition(
                                    turns: Tween(begin: 0.0, end: 1.0)
                                        .animate(_animationController),
                                    child: Icon(
                                      Icons.local_shipping_rounded,
                                      size: 55,
                                      color: primaryColor,
                                    ),
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
                                    fontWeight: FontWeight.w500),
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
