import 'package:flutter/material.dart';
import '../../services/firestore_Service.dart';

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

  // ===========================================================================
  // 🔥 FIREBASE: Kullanıcı Ekleme (PLAKA SORUNU DÜZELTİLDİ)
  // ===========================================================================
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

  // ===========================================================================
  // 🔧 UI: Input Decoration (JobsPage Style)
  // ===========================================================================
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

  // ===========================================================================
  // FORM ELEMANLARI
  // ===========================================================================
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

  // ===========================================================================
  // ROLE SELECTOR (JobsPage Tarzında Segment Control)
  // ===========================================================================
  Widget _roleSelector() {
    Widget button(String key, String label, IconData icon) {
      final selected = _role == key;

      return InkWell(
        onTap: () => setState(() => _role = key),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AddUserPage.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        button("driver", "Şoför", Icons.local_shipping_outlined),
        const SizedBox(width: 12),
        button("dispatch", "Dispatch", Icons.support_agent_outlined),
      ],
    );
  }

  // ===========================================================================
  // SUBMIT BUTTON
  // ===========================================================================
  Widget _submitBtn(bool desktop) {
    return SizedBox(
      width: desktop ? 240 : double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _addUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AddUserPage.primary,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Text("Kullanıcı Ekle",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ===========================================================================
  // DESKTOP UI (Modern JobsPage Style)
  // ===========================================================================
  Widget _desktop() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Row(
          children: [
            // SOL PANEL (GRADIENT)
            Expanded(
              flex: 4,
              child: Container(
                height: 480,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: Offset(0, 10)),
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.admin_panel_settings,
                          size: 42, color: Colors.white),
                      const SizedBox(height: 18),
                      const Text("Yönetici Kullanıcı Oluşturma",
                          style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        "Sisteme yeni sürücü veya dispatch ekleyin.",
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(.85)),
                      ),
                      const Spacer(),
                      _infoBox(),
                    ]),
              ),
            ),

            const SizedBox(width: 28),

            // FORM PANEL
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

  Widget _infoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Dispatch kullanıcıları iş ataması yapar; sürücüler yalnızca kendilerine atanmış işleri görür.",
              style: TextStyle(
                  color: Colors.white.withOpacity(.9), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE UI
  // ===========================================================================
  Widget _mobile() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 HEADER (AYNISI)
                  _buildHeader(),
                  const SizedBox(height: 20),
                  // FORM
                  _form(desktop: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Kullanıcı Ekle",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Yeni şoför veya dispatch kullanıcısı ekleyin",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // ===========================================================================
  // BUILD
  // ===========================================================================
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
          // AD SOYAD + EMAIL
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

          // TELEFON + PLAKA
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

          _roleSelector(),

          const SizedBox(height: 28),

          _submitBtn(desktop),
        ],
      ),
    );
  }

}
