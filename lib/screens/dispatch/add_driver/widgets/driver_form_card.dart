// 📁 lib/pages/widgets/driver_form_card.dart
import 'package:flutter/material.dart';

class DriverFormCard extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController plateController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onSubmit;

  const DriverFormCard({
    super.key,
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.plateController,
    required this.passwordController,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  State<DriverFormCard> createState() => _DriverFormCardState();
}

class _DriverFormCardState extends State<DriverFormCard> {
  bool _passwordVisible = false;

  static const Color accent = Color(0xFF3B82F6);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  InputDecoration _inputDecoration(String label, IconData icon, {bool isPassword = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: textSecondary, size: 18),
      suffixIcon: isPassword
          ? IconButton(
        icon: Icon(
          _passwordVisible ? Icons.visibility_off : Icons.visibility,
          color: textSecondary,
          size: 18,
        ),
        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
      )
          : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // İsim Soyisim
          TextField(
            controller: widget.nameController,
            decoration: _inputDecoration("İsim Soyisim", Icons.person_outline),
          ),
          const SizedBox(height: 12),

          // E-posta
          TextField(
            controller: widget.emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration("E-posta", Icons.email_outlined),
          ),
          const SizedBox(height: 12),

          // Telefon
          TextField(
            controller: widget.phoneController,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration("Telefon", Icons.phone_outlined),
          ),
          const SizedBox(height: 12),

          // Plaka
          TextField(
            controller: widget.plateController,
            decoration: _inputDecoration("Plaka", Icons.badge_outlined),
          ),
          const SizedBox(height: 12),

          // Şifre
          TextField(
            controller: widget.passwordController,
            obscureText: !_passwordVisible,
            decoration: _inputDecoration("Şifre (min. 6 karakter)", Icons.lock_outline, isPassword: true),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add, size: 22),
                  SizedBox(width: 10),
                  Text(
                    "Şoförü Ekle",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}