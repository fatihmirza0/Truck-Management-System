import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddDriverPage extends StatefulWidget {
  const AddDriverPage({super.key});

  @override
  State<AddDriverPage> createState() => _AddDriverPageState();
}

class _AddDriverPageState extends State<AddDriverPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  bool _isLoading = false;

  String? _dispatchUid;
  bool _isLoadingDispatch = true;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _loadDispatchUid();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Giriş yapan dispatch’in UID’sini al
  // ---------------------------------------------------------------------------
  Future<void> _loadDispatchUid() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) {
        setState(() => _isLoadingDispatch = false);
        return;
      }

      _dispatchUid = uid;
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) {
        setState(() => _isLoadingDispatch = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DRIVER EKLE (UID TABANLI + jobStatus)
  // ---------------------------------------------------------------------------
  Future<void> _addDriver() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final plate = _plateController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty ||
        plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun")),
      );
      return;
    }

    if (_dispatchUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Dispatch bilgileriniz yüklenemedi."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      /// 1) Firebase Auth'ta account oluştur
      UserCredential credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final driverUid = credential.user!.uid;

      /// 2) Firestore'a kayıt
      await FirebaseFirestore.instance.collection('users').doc(driverUid).set({
        'uid': driverUid,
        'role': 'driver',
        'name': name,
        'email': email,
        'phone': phone,
        'plateNumber': plate,
        'createdBy': _dispatchUid,
        'createdAt': Timestamp.now(),
        'jobStatus': 'available', // 🔥 Yeni eklenen sürücü BOŞTA
      });

      /// Formu temizle
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _plateController.clear();

      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 160));
      await _animationController.reverse();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.blueAccent,
            content: Text("$name başarıyla eklendi"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // TEXTFIELD
  // ---------------------------------------------------------------------------
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isPassword = false,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
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
          borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007AFF);

    if (_isLoadingDispatch) {
      return const Center(child: CircularProgressIndicator());
    }

    return isDesktop
        ? _buildDesktopLayout(primaryColor)
        : _buildMobileLayout(primaryColor);
  }

  // ---------------------------------------------------------------------------
  // MOBILE
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(Color primaryColor) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _formContent(primaryColor),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(Color primaryColor) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 420,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF16A085)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_shipping,
                          size: 48, color: Colors.white),
                      const SizedBox(height: 18),
                      const Text(
                        "Şoför Kadrosu",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Yeni sürücüler ekleyerek sevkiyat kapasitenizi "
                            "ve operasyon verimliliğinizi artırın.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Her sürücü benzersiz bir \"driverId\" ve "
                                    "kayıtlı telefon/plaka bilgileriyle tutulur.",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),              const SizedBox(width: 24),
              Expanded(
                flex: 5,
                child: Container(
                  height: 430,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _formContent(primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM
  // ---------------------------------------------------------------------------
  Widget _formContent(Color primaryColor) {
    return Column(
      children: [
        _buildTextField(_nameController, "İsim", Icons.person),
        const SizedBox(height: 12),
        _buildTextField(_emailController, "E-posta", Icons.email),
        const SizedBox(height: 12),
        _buildTextField(
          _phoneController,
          "Telefon",
          Icons.phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildTextField(_plateController, "Plaka", Icons.directions_car),
        const SizedBox(height: 12),
        _buildTextField(
          _passwordController,
          "Şifre",
          Icons.lock,
          isPassword: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _addDriver,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2.2,
            )
                : const Text(
              "Şoförü Ekle",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
