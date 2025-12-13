import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  bool _isLoading = false;
  bool _passwordVisible = false;

  String? _dispatchUid;
  bool _isLoadingDispatch = true;

  late AnimationController _formController;
  late Animation<double> _formAnimation;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  static const Color primary = Color(0xFF1E293B);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentLight = Color(0xFFEFF6FF);
  static const Color success = Color(0xFF10B981);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadDispatchUid();

    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _formAnimation = CurvedAnimation(
      parent: _formController,
      curve: Curves.easeOutCubic,
    );

    _formController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _loadDispatchUid() async {
    try {
      _dispatchUid = FirebaseAuth.instance.currentUser?.uid;
    } finally {
      if (mounted) setState(() => _isLoadingDispatch = false);
    }
  }

  Future<void> _addDriver() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final plate = _plateController.text.trim();

    if ([name, email, password, phone, plate].any((e) => e.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen tüm alanları doldurun"),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (_dispatchUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dispatch bilgisi bulunamadı")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final driverUid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(driverUid).set({
        'uid': driverUid,
        'role': 'driver',
        'name': name,
        'email': email,
        'phone': phone,
        'plateNumber': plate,
        'createdBy': _dispatchUid,
        'createdAt': Timestamp.now(),
        'jobStatus': 'available',
      });

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _plateController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✓ $name başarıyla eklendi"),
          backgroundColor: success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _input(String label, IconData icon, {bool isPassword = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      suffixIcon: isPassword
          ? IconButton(
        icon: Icon(
          _passwordVisible ? Icons.visibility_off : Icons.visibility,
          color: textSecondary,
          size: 20,
        ),
        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
      )
          : null,
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool isPassword = false,
    int delay = 0,
  }) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? !_passwordVisible : obscureText,
        decoration: _input(label, icon, isPassword: isPassword),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDispatch) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: bg,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                FadeTransition(
                  opacity: _formAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(_formAnimation),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A5F), primary.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Şoför Ekle",
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Yeni şoför kaydı oluşturun",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Form Card
                FadeTransition(
                  opacity: _formAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(_formAnimation),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Şoför Bilgileri",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildFormField(
                            controller: _nameController,
                            label: "İsim Soyisim",
                            icon: Icons.person_outline,
                            delay: 0,
                          ),
                          const SizedBox(height: 12),

                          _buildFormField(
                            controller: _emailController,
                            label: "E-posta",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            delay: 50,
                          ),
                          const SizedBox(height: 12),

                          _buildFormField(
                            controller: _phoneController,
                            label: "Telefon",
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            delay: 100,
                          ),
                          const SizedBox(height: 12),

                          _buildFormField(
                            controller: _plateController,
                            label: "Plaka",
                            icon: Icons.badge_outlined,
                            delay: 150,
                          ),
                          const SizedBox(height: 12),

                          _buildFormField(
                            controller: _passwordController,
                            label: "Şifre",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            delay: 200,
                          ),

                          const SizedBox(height: 24),

                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            builder: (context, double value, child) {
                              return Transform.scale(
                                scale: 0.95 + (0.05 * value),
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _addDriver,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  "Şoförü Ekle",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Card
                FadeTransition(
                  opacity: _formAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: accent, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Eklenen şoför otomatik olarak sisteme kaydedilir ve giriş yapabilir.",
                            style: TextStyle(
                              fontSize: 13,
                              color: textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}