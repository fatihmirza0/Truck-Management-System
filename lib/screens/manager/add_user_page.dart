import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: _selectedRole)
          .get();

      final newId =
          '${_selectedRole}${(snapshot.size + 1).toString().padLeft(3, '0')}';

      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'phone': _phoneController.text.trim(),
        'roleId': _selectedRole,
        if (_selectedRole == 'driver') 'driverId': newId,
        if (_selectedRole == 'driver')
          'plateNumber': _plateController.text.trim().toUpperCase(),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
          _selectedRole == 'driver' ? Colors.blue[700] : Colors.orange[700],
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Kullanıcı başarıyla eklendi"),
            ],
          ),
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

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        bool isPassword = false,
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: _selectedRole == 'driver'
                ? Colors.blueAccent
                : Colors.orangeAccent,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
    _selectedRole == 'driver' ? Colors.blueAccent : Colors.orangeAccent;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedRole == 'driver'
                              ? Icons.local_shipping
                              : Icons.support_agent,
                          color: primaryColor,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Kullanıcı Bilgileri",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const Divider(height: 32),

                        _buildTextField(
                          _nameController,
                          "İsim",
                          validator: (val) =>
                          val == null || val.isEmpty ? "Zorunlu alan" : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _emailController,
                          "E-posta",
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Zorunlu alan";
                            if (!val.contains('@')) return "Geçerli e-posta girin";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _passwordController,
                          "Şifre",
                          isPassword: true,
                          validator: (val) =>
                          val == null || val.length < 6 ? "En az 6 karakter" : null,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _phoneController,
                          "Telefon Numarası",
                          keyboardType: TextInputType.phone,
                          validator: (val) =>
                          val == null || val.length < 10 ? "Geçersiz numara" : null,
                        ),
                        if (_selectedRole == 'driver') ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            _plateController,
                            "Plaka No",
                            validator: (val) => val == null || val.isEmpty
                                ? "Zorunlu alan"
                                : null,
                          ),
                        ],

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text("Şoför"),
                              selected: _selectedRole == 'driver',
                              onSelected: (_) =>
                                  setState(() => _selectedRole = 'driver'),
                              selectedColor: Colors.blue.shade50,
                              labelStyle: TextStyle(
                                color: _selectedRole == 'driver'
                                    ? Colors.blueAccent
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text("Dispatch"),
                              selected: _selectedRole == 'dispatch',
                              onSelected: (_) =>
                                  setState(() => _selectedRole = 'dispatch'),
                              selectedColor: Colors.orange.shade50,
                              labelStyle: TextStyle(
                                color: _selectedRole == 'dispatch'
                                    ? Colors.orangeAccent
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _addUser,
                            icon: _isLoading
                                ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.person_add_alt_1),
                            label: const Text(
                              "Kullanıcıyı Ekle",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
          ),
        ),
      ),
    );
  }
}
