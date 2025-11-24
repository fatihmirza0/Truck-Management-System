import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  String _selectedRole = 'driver';
  bool _isLoading = false;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;
      final roleBasedId = _selectedRole == 'driver'
          ? 'driver${DateTime.now().millisecondsSinceEpoch}'
          : 'dispatch${DateTime.now().millisecondsSinceEpoch}';

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'roleId': _selectedRole,
        if (_selectedRole == 'driver') 'driverId': roleBasedId,
        if (_selectedRole == 'driver')
          'plateNumber': _plateController.text.trim().toUpperCase(),
        if (_selectedRole == 'dispatch') 'dispatchId': roleBasedId,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Kullanıcı başarıyla eklendi"),
          backgroundColor: Colors.green,
        ),
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _plateController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: _inputDecoration("İsim"),
            validator: (val) => val == null || val.isEmpty ? "Zorunlu alan" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: _inputDecoration("E-posta"),
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.isEmpty) return "Zorunlu alan";
              if (!val.contains('@')) return "Geçerli e-posta girin";
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: _inputDecoration("Şifre"),
            obscureText: true,
            validator: (val) =>
            val == null || val.length < 6 ? "En az 6 karakter" : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: _inputDecoration("Telefon Numarası"),
            keyboardType: TextInputType.phone,
            validator: (val) =>
            val == null || val.length < 10 ? "Geçersiz numara" : null,
          ),
          if (_selectedRole == 'driver') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _plateController,
              decoration: _inputDecoration("Plaka No"),
              validator: (val) => val == null || val.isEmpty ? "Zorunlu alan" : null,
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              ChoiceChip(
                label: const Text("Şoför"),
                selected: _selectedRole == 'driver',
                selectedColor: Colors.grey[300],
                backgroundColor: Colors.grey[200],
                onSelected: (_) => setState(() => _selectedRole = 'driver'),
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text("Dispatch"),
                selected: _selectedRole == 'dispatch',
                selectedColor: Colors.grey[300],
                backgroundColor: Colors.grey[200],
                onSelected: (_) => setState(() => _selectedRole = 'dispatch'),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 180,
            height: 44,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                "Kullanıcı Ekle",
                style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Yeni Kullanıcı Oluştur",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Yeni kullanıcı bilgilerini girerek sisteme ekleyin.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                _buildForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Yeni Kullanıcı Oluştur",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Yeni kullanıcı bilgilerini girerek sisteme ekleyin.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          _buildForm(),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }
}
