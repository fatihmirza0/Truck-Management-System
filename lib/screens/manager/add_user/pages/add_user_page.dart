import 'package:flutter/material.dart';
import '../../../../services/firestore_service.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/animated/animated_widgets.dart';

import '../widgets/add_user_header.dart';
import '../widgets/role_selector.dart';
import '../widgets/add_user_submit_button.dart';
import '../widgets/add_user_info_box.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();

  bool _loading = false;
  String _role = "driver";

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirestoreService.createUserHttp(
        name: _name.text,
        email: _email.text,
        password: _pass.text,
        phone: _phone.text,
        role: _role,
        plate: _role == "driver" ? _plate.text : null,
      );

      if (mounted) {
        _clear();
        _snack("Kullanıcı başarıyla eklendi", true);
      }
    } catch (e) {
      if (mounted) _snack("Hata: $e");
    }

    if (mounted) setState(() => _loading = false);
  }

  void _clear() {
    _name.clear();
    _email.clear();
    _pass.clear();
    _phone.clear();
    _plate.clear();
  }

  void _snack(String msg, [bool success = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
      hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
      labelStyle: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return TextFormField(
      controller: c,
      style: const TextStyle(fontSize: 13.5),
      decoration: _dec(label, icon),
      validator: (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null,
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _email,
      style: const TextStyle(fontSize: 13.5),
      decoration: _dec("E-posta", Icons.email_outlined),
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
          v != null && v.contains("@") ? null : "Geçerli e-posta girin",
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phone,
      style: const TextStyle(fontSize: 13.5),
      decoration: _dec("Telefon", Icons.phone_outlined),
      keyboardType: TextInputType.phone,
      validator: (v) =>
          v != null && v.length >= 10 ? null : "En az 10 karakter olmalı",
    );
  }

  Widget _plateField() {
    return TextFormField(
      controller: _plate,
      style: const TextStyle(fontSize: 13.5),
      decoration: _dec("Araç Plakası", Icons.badge_outlined),
      validator: (v) => v == null || v.isEmpty ? "Plaka zorunlu" : null,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _pass,
      style: const TextStyle(fontSize: 13.5),
      obscureText: true,
      decoration: _dec("Şifre", Icons.lock_outline_rounded),
      validator: (v) =>
          v != null && v.length >= 6 ? null : "Min 6 karakter olmalı",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 20,
              vertical: isDesktop ? 32 : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 750 : 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SlideInWidget(
                    child: AddUserHeader(isDesktop: isDesktop),
                  ),
                  const SizedBox(height: 24),
                  const SlideInWidget(
                    delay: Duration(milliseconds: 100),
                    child: AddUserInfoBox(),
                  ),
                  const SizedBox(height: 24),
                  SlideInWidget(
                    delay: const Duration(milliseconds: 200),
                    child: AnimatedCard(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 32 : 24),
                        child: _form(desktop: isDesktop),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Extra space at the bottom
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form({required bool desktop}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field(_name, "Ad Soyad", Icons.person_outline_rounded),
          const SizedBox(height: 20),
          _emailField(),
          const SizedBox(height: 20),
          if (desktop)
            Row(
              children: [
                Expanded(child: _phoneField()),
                if (_role == "driver") ...[
                  const SizedBox(width: 16),
                  Expanded(child: _plateField()),
                ],
              ],
            )
          else ...[
            _phoneField(),
            if (_role == "driver") ...[
              const SizedBox(height: 20),
              _plateField(),
            ],
          ],
          const SizedBox(height: 20),
          _passwordField(),
          const SizedBox(height: 28),
          Text(
            "Kullanıcı Rolü",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          RoleSelector(
            selectedRole: _role,
            onRoleChanged: (role) => setState(() => _role = role),
          ),
          const SizedBox(height: 36),
          Center(
            child: AddUserSubmitButton(
              loading: _loading,
              onPressed: _addUser,
              isDesktop: desktop,
            ),
          ),
        ],
      ),
    );
  }
}
