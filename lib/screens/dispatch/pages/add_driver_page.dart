// 📁 lib/pages/add_driver_page.dart
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';
import 'widgets/form_header.dart';
import 'widgets/driver_form_card.dart';
import 'widgets/info_banner.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  bool _isLoading = false;

  // 🎨 Color Palette
  static const Color primary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color bg = Color(0xFFF8FAFC);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _addDriver() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final plate = _plateController.text.trim();

    // Validation
    if (name.isEmpty) {
      _showSnackBar("Lütfen isim soyisim giriniz", isError: true);
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _showSnackBar("Lütfen geçerli bir e-posta adresi giriniz", isError: true);
      return;
    }

    if (password.isEmpty || password.length < 6) {
      _showSnackBar("Şifre en az 6 karakter olmalıdır", isError: true);
      return;
    }

    if (phone.isEmpty) {
      _showSnackBar("Lütfen telefon numarası giriniz", isError: true);
      return;
    }

    if (plate.isEmpty) {
      _showSnackBar("Lütfen plaka giriniz", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirestoreService.createDriverHttp(
        name: name,
        email: email,
        password: password,
        phone: phone,
        plate: plate,
      );

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _plateController.clear();

      _showSnackBar("✓ $name başarıyla eklendi", isError: false);
    } catch (e) {
      String errorMessage = "Bir hata oluştu";

      if (e.toString().contains('email-already-in-use')) {
        errorMessage = "Bu e-posta adresi zaten kullanımda";
      } else if (e.toString().contains('weak-password')) {
        errorMessage = "Şifre çok zayıf";
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = "Geçersiz e-posta adresi";
      } else if (e.toString().contains('Sadece dispatch')) {
        errorMessage = "Sadece dispatch kullanıcıları şoför ekleyebilir";
      } else {
        errorMessage = "Hata: ${e.toString()}";
      }

      _showSnackBar(errorMessage, isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? error : success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 Header
            const FormHeader(
              icon: Icons.person_add_alt,
              title: "Yeni Şoför Ekle",
              subtitle: "Sisteme yeni şoför kaydı oluşturun",
            ),
            const SizedBox(height: 32),

            // 📝 Form Card
            DriverFormCard(
              nameController: _nameController,
              emailController: _emailController,
              phoneController: _phoneController,
              plateController: _plateController,
              passwordController: _passwordController,
              isLoading: _isLoading,
              onSubmit: _addDriver,
            ),
            const SizedBox(height: 16),

            // ℹ️ Info Banner
            const InfoBanner(
              icon: Icons.info_outline,
              message: "Eklenen şoför için otomatik olarak bir kullanıcı hesabı ve araç kaydı oluşturulur.",
            ),
          ],
        ),
      ),
    );
  }
}