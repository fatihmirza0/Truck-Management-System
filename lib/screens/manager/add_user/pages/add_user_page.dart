import 'package:flutter/material.dart';
import '../../../../services/firestore_Service.dart';

import '../widgets/add_user_header.dart';
import '../widgets/role_selector.dart';
import '../widgets/add_user_submit_button.dart';
import '../widgets/add_user_desktop_panel.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);

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

      _clear();
      _snack("Kullanıcı başarıyla eklendi", true);
    } catch (e) {
      _snack("Hata: $e");
    }

    setState(() => _loading = false);
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
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Color(0xFF64748B)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AddUserPage.primary, width: 2),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      decoration: _dec(label),
      validator: (v) => v == null || v.isEmpty ? "Bu alan zorunlu" : null,
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _email,
      decoration: _dec("E-posta"),
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
      v != null && v.contains("@") ? null : "Geçerli e-posta girin",
    );
  }

  Widget _phoneField() {
    return TextFormField(
      controller: _phone,
      decoration: _dec("Telefon"),
      keyboardType: TextInputType.phone,
      validator: (v) =>
      v != null && v.length >= 10 ? null : "Telefon numarası geçersiz",
    );
  }

  Widget _plateField() {
    return TextFormField(
      controller: _plate,
      decoration: _dec("Plaka"),
      validator: (v) => v == null || v.isEmpty ? "Plaka zorunlu" : null,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _pass,
      obscureText: true,
      decoration: _dec("Şifre"),
      validator: (v) =>
      v != null && v.length >= 6 ? null : "Min 6 karakter olmalı",
    );
  }

  Widget _desktop() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: AddUserDesktopPanel(
                child: Container(),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Yeni Kullanıcı Oluştur",
                            style: TextStyle(
                                fontSize: 20,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          "Kullanıcı bilgilerini doldurun.",
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        _form(desktop: true),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobile() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AddUserHeader(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _form(desktop: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddUserPage.bg,
      body: isDesktop ? _desktop() : _mobile(),
    );
  }
  Widget _form({required bool desktop}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(child: _field(_name, "Ad Soyad")),
                const SizedBox(width: 16),
                Expanded(child: _emailField()),
              ],
            )
          else ...[
            _field(_name, "Ad Soyad"),
            const SizedBox(height: 16),
            _emailField(),
          ],
          const SizedBox(height: 18),
          if (desktop)
            Row(
              children: [
                Expanded(child: _phoneField()),
                const SizedBox(width: 16),
                if (_role == "driver") Expanded(child: _plateField()),
              ],
            )
          else ...[
            _phoneField(),
            if (_role == "driver") ...[
              const SizedBox(height: 16),
              _plateField(),
            ],
          ],
          const SizedBox(height: 18),
          _passwordField(),
          const SizedBox(height: 28),
          RoleSelector(
            selectedRole: _role,
            onRoleChanged: (role) => setState(() => _role = role),
          ),
          const SizedBox(height: 28),
          AddUserSubmitButton(
            loading: _loading,
            onPressed: _addUser,
            isDesktop: desktop,
          ),
        ],
      ),
    );
  }
}

