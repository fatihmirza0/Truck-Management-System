// lib/screens/manager/add_user_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedRole = 'driver';
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation =
        Tween<double>(begin: 1, end: 1.03).animate(CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        ));
  }

  Future<void> _addUser() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: _selectedRole)
          .get();

      final newId =
          '${_selectedRole}${(snapshot.size + 1).toString().padLeft(3, '0')}';

      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'email': email,
        'password': password,
        'roleId': _selectedRole,
        if (_selectedRole == 'driver') 'driverId': newId,
        'createdAt': Timestamp.now(),
      });

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();

      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      await _animationController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _selectedRole == 'driver'
              ? Colors.blueAccent
              : Colors.orangeAccent,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text("$name başarıyla eklendi",
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: _selectedRole == 'driver'
                    ? Colors.blueAccent
                    : Colors.orangeAccent,
                width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _selectedRole == 'driver'
        ? const Color(0xFF007AFF)
        : const Color(0xFFFF9500);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    _selectedRole == 'driver'
                        ? Icons.local_shipping
                        : Icons.support_agent,
                    color: primaryColor,
                    size: 60,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Yeni Kullanıcı Ekle",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Alanlar
                  _buildTextField(_nameController, "İsim", Icons.person),
                  const SizedBox(height: 14),
                  _buildTextField(_emailController, "E-posta", Icons.email),
                  const SizedBox(height: 14),
                  _buildTextField(
                      _passwordController, "Şifre", Icons.lock,
                      isPassword: true),
                  const SizedBox(height: 24),

                  // Rol seçimi
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ChoiceChip(
                          label: const Text("Şoför"),
                          selected: _selectedRole == 'driver',
                          selectedColor: Colors.blueAccent.withOpacity(0.2),
                          onSelected: (_) {
                            setState(() => _selectedRole = 'driver');
                          },
                          labelStyle: TextStyle(
                            color: _selectedRole == 'driver'
                                ? Colors.blueAccent
                                : Colors.black87,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text("Dispatch"),
                          selected: _selectedRole == 'dispatch',
                          selectedColor: Colors.orangeAccent.withOpacity(0.2),
                          onSelected: (_) {
                            setState(() => _selectedRole = 'dispatch');
                          },
                          labelStyle: TextStyle(
                            color: _selectedRole == 'dispatch'
                                ? Colors.orangeAccent
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Gradient buton
                  GestureDetector(
                    onTap: _isLoading ? null : _addUser,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedRole == 'driver'
                              ? [Colors.blueAccent, Colors.lightBlue]
                              : [Colors.orangeAccent, Colors.deepOrange],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                          color: Colors.white)
                          : const Text(
                        "Kullanıcıyı Ekle",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
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
