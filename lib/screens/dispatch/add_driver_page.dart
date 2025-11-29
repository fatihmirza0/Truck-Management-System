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

  String? _dispatchId;
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

    _loadCurrentDispatchId();
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
  // Mevcut dispatch kullanıcısının dispatchId'si
  // ---------------------------------------------------------------------------
  Future<void> _loadCurrentDispatchId() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingDispatch = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        _dispatchId = doc.data()?['dispatchId'] as String?;
      }
    } catch (_) {
      // sessiz hata
    } finally {
      if (mounted) {
        setState(() => _isLoadingDispatch = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Driver ekle
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

    if (_dispatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Dispatch bilgileri yüklenemedi. Lütfen tekrar giriş yapmayı deneyin."),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'driver')
          .get();

      final newId = 'driver${(snapshot.size + 1).toString().padLeft(3, '0')}';

      await FirebaseFirestore.instance.collection('users').add({
        'name': name,
        'email': email,
        'password': password, // prod'da plaintext tutma :)
        'phone': phone,
        'plateNumber': plate,
        'roleId': 'driver',
        'driverId': newId,
        'dispatchId': _dispatchId,
        'createdAt': Timestamp.now(),
      });

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _phoneController.clear();
      _plateController.clear();

      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      await _animationController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.blueAccent,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                "$name başarıyla eklendi",
                style: const TextStyle(color: Colors.white),
              ),
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

  // ---------------------------------------------------------------------------
  // Ortak TextField
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
  // 📱 MOBİL UI
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(Color primaryColor) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
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
                child: _formContent(primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥️ DESKTOP UI
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(Color primaryColor) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
              // Sol bilgi paneli
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
              ),
              const SizedBox(width: 28),
              // Sağ form paneli
              Expanded(
                flex: 5,
                child: Container(
                  height: 420,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                  child: _formContent(primaryColor, isDesktop: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ortak form içeriği
  // ---------------------------------------------------------------------------
  Widget _formContent(Color primaryColor, {bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
          Icon(Icons.local_shipping, color: primaryColor, size: 40),
          const SizedBox(height: 8),
        ],
        Text(
          "Yeni Şoför Ekle",
          style: TextStyle(
            fontSize: isDesktop ? 20 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 18),

        if (isDesktop) ...[
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                    _nameController, "İsim", Icons.person),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                    _emailController, "E-posta", Icons.email),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _phoneController,
                  "Telefon",
                  Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _plateController,
                  "Plaka",
                  Icons.directions_car,
                  keyboardType: TextInputType.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _passwordController,
            "Şifre",
            Icons.lock,
            isPassword: true,
          ),
        ] else ...[
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
          _buildTextField(
            _plateController,
            "Plaka",
            Icons.directions_car,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _passwordController,
            "Şifre",
            Icons.lock,
            isPassword: true,
          ),
        ],

        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _addDriver,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
                : const Text(
              "Şoförü Ekle",
              style:
              TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
