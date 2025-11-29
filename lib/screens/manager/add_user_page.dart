import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  static const Color accent = Color(0xFF2563EB);
  static const Color bg = Color(0xFFF7F8FA);

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

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  String _role = "driver";
  bool _loading = false;

  // ---------------------------------------------------------------------------
  // FIREBASE: Kullanıcı ekleme
  // ---------------------------------------------------------------------------
  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final auth = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      final uid = auth.user!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final roleId = "${_role == 'driver' ? 'driver' : 'dispatch'}$timestamp";

      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": _name.text.trim(),
        "email": _email.text.trim(),
        "phone": _phone.text.trim(),
        "roleId": _role,
        if (_role == "driver") "driverId": roleId,
        if (_role == "driver") "plateNumber": _plate.text.trim().toUpperCase(),
        if (_role == "dispatch") "dispatchId": roleId,
        "createdAt": Timestamp.now(),
      });

      _clearForm();
      _snack("Kullanıcı başarıyla eklendi", true);
    } catch (e) {
      _snack("Hata: $e");
    }

    setState(() => _loading = false);
  }

  void _clearForm() {
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

  // ---------------------------------------------------------------------------
  // INPUT DECORATION (Tek yerden kontrol)
  // ---------------------------------------------------------------------------
  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(color: Colors.grey),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AddUserPage.accent, width: 2),
    ),
  );

  // ---------------------------------------------------------------------------
  // TEK FORM YAPISI
  // ---------------------------------------------------------------------------
  Widget _form({required bool desktop}) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (desktop)
            Row(children: [
              _field(_name, "İsim"),
              const SizedBox(width: 12),
              _emailField(),
            ])
          else ...[
            _field(_name, "İsim"),
            const SizedBox(height: 16),
            _emailField(),
          ],

          const SizedBox(height: 16),

          if (desktop)
            Row(children: [
              _phoneField(),
              const SizedBox(width: 12),
              if (_role == "driver") _plateField(),
            ])
          else ...[
            _phoneField(),
            if (_role == "driver") ...[
              const SizedBox(height: 16),
              _plateField(),
            ]
          ],

          const SizedBox(height: 16),
          _passwordField(),

          const SizedBox(height: 24),
          _roleChips(),

          const SizedBox(height: 28),
          _submitButton(desktop),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM ELEMENTLERİ
  // ---------------------------------------------------------------------------

  Widget _field(TextEditingController c, String label) =>
      Expanded(child: TextFormField(controller: c, decoration: _dec(label), validator: _required));

  Widget _emailField() => Expanded(
    child: TextFormField(
      controller: _email,
      decoration: _dec("E-posta"),
      keyboardType: TextInputType.emailAddress,
      validator: (v) =>
      v == null || !v.contains("@") ? "Geçerli e-posta girin" : null,
    ),
  );

  Widget _phoneField() => Expanded(
    child: TextFormField(
      controller: _phone,
      decoration: _dec("Telefon Numarası"),
      keyboardType: TextInputType.phone,
      validator: (v) => v == null || v.length < 10 ? "Geçersiz numara" : null,
    ),
  );

  Widget _plateField() => Expanded(
    child: TextFormField(
      controller: _plate,
      decoration: _dec("Plaka No"),
      validator: _required,
    ),
  );

  Widget _passwordField() => TextFormField(
    controller: _pass,
    decoration: _dec("Şifre"),
    obscureText: true,
    validator: (v) => v != null && v.length >= 6 ? null : "En az 6 karakter",
  );

  String? _required(String? v) => v == null || v.isEmpty ? "Zorunlu alan" : null;

  // ---------------------------------------------------------------------------
  // ROLE CHIPS
  // ---------------------------------------------------------------------------
  Widget _roleChips() {
    Widget chip(String key, String text) {
      final selected = _role == key;
      return ChoiceChip(
        label: Text(text),
        selected: selected,
        selectedColor: AddUserPage.accent.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? AddUserPage.accent : Colors.grey[700],
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
        onSelected: (_) => setState(() => _role = key),
      );
    }

    return Wrap(
      spacing: 12,
      children: [
        chip("driver", "Şoför"),
        chip("dispatch", "Dispatch"),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUBMIT BUTTON
  // ---------------------------------------------------------------------------
  Widget _submitButton(bool desktop) {
    return SizedBox(
      width: desktop ? 220 : double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: _loading ? null : _addUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: AddUserPage.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _loading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Text("Kullanıcı Ekle",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT
  // (Yükseklik sorunu çözüldü — height kaldırıldı)
  // ---------------------------------------------------------------------------
  Widget _desktop() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Row(children: [
          Expanded(flex: 4, child: _leftInfoCard()),
          const SizedBox(width: 28),
          Expanded(flex: 5, child: _rightFormCard()),
        ]),
      ),
    );
  }

  Widget _leftInfoCard() {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.admin_panel_settings, color: Colors.white, size: 46),
        const SizedBox(height: 18),
        const Text("Yönetici Kullanıcı Oluşturma",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(
          "Sürücü ve dispatch kullanıcıları ekleyerek sistemi yönetin.",
          style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 14),
        ),
        const Spacer(),
        _infoBox(),
      ]),
    );
  }

  Widget _infoBox() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, color: Colors.white),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          "Dispatch kullanıcıları iş ataması yapar, sürücüler atanan işleri görür.",
          style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 13),
        ),
      )
    ]),
  );

  Widget _rightFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Yeni Kullanıcı Oluştur",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text("Kullanıcı bilgilerini girerek sisteme ekleyin.",
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          _form(desktop: true),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT
  // ---------------------------------------------------------------------------
  Widget _mobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Yeni Kullanıcı Oluştur",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              const SizedBox(height: 8),
              Text("Kullanıcı bilgilerini girerek sisteme ekleyin.",
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 20),
              _form(desktop: false),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AddUserPage.bg,
      body: isDesktop ? _desktop() : _mobile(),
    );
  }
}
