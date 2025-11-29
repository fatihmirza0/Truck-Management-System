import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _loadPortController = TextEditingController();
  final TextEditingController _unloadPortController = TextEditingController();
  final TextEditingController _cargoInfoController = TextEditingController();

  String? _selectedDriver;
  bool _isCreatingJob = false;

  /// Giriş yapan dispatch kullanıcısının Firestore'daki dispatchId alanı
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
    _loadPortController.dispose();
    _unloadPortController.dispose();
    _cargoInfoController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Giriş yapan dispatch kullanıcısının dispatchId'sini yükle
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
      // Hata olsa da formu tamamen kilitlemeyelim
    } finally {
      if (mounted) {
        setState(() => _isLoadingDispatch = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 Şoförleri çek
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('roleId', isEqualTo: 'driver')
        .get();

    return snapshot.docs
        .map((doc) => {
      'id': doc.id,
      'name': doc['name'] ?? 'Bilinmeyen',
      'driverId': doc['driverId'] ?? '',
    })
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Job oluştur
  // ---------------------------------------------------------------------------
  Future<void> _createJob() async {
    final loadPort = _loadPortController.text.trim();
    final unloadPort = _unloadPortController.text.trim();
    final cargoInfo = _cargoInfoController.text.trim();

    if (loadPort.isEmpty ||
        unloadPort.isEmpty ||
        cargoInfo.isEmpty ||
        _selectedDriver == null) {
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

    setState(() => _isCreatingJob = true);

    try {
      await FirebaseFirestore.instance.collection('jobs').add({
        'loadPort': loadPort,
        'unloadPort': unloadPort,
        'cargoInfo': cargoInfo,
        'assignedTo': _selectedDriver, // driverId
        'assignedBy': _dispatchId, // 🔹 Firestore’daki dispatchId
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      _loadPortController.clear();
      _unloadPortController.clear();
      _cargoInfoController.clear();
      setState(() => _selectedDriver = null);

      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 150));
      await _animationController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blueAccent,
          content: Text("Görev başarıyla oluşturuldu"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: ${e.toString()}")),
      );
    } finally {
      setState(() => _isCreatingJob = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 Ortak textfield
  // ---------------------------------------------------------------------------
  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
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
  // 🔹 BUILD
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
  // 📱 MOBİL UI (revize)
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
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: _formContent(primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥️ DESKTOP UI (sıfırdan tasarım)
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
                      colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
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
                        "Yeni Sevkiyat Oluştur",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Alış – varış limanlarını, yük bilgisini ve sürücüyü seçerek "
                            "dakikalar içinde yeni bir iş ataması yapın.",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
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
                                "Oluşturulan tüm işler varsayılan olarak "
                                    "\"pending\" durumunda başlar.",
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
  // 🔹 Ortak form içeriği (mobil + desktop)
  // ---------------------------------------------------------------------------
  Widget _formContent(Color primaryColor, {bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop) ...[
          Icon(Icons.assignment, color: primaryColor, size: 40),
          const SizedBox(height: 8),
        ],
        Text(
          "Yeni İş Ekle",
          style: TextStyle(
            fontSize: isDesktop ? 20 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 18),

        // 2 kolonlu layout (desktop) / tek kolon (mobil)
        if (isDesktop)
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                    _loadPortController, "Alış Limanı", Icons.anchor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                    _unloadPortController, "Varış Limanı", Icons.flag),
              ),
            ],
          )
        else ...[
          _buildTextField(
              _loadPortController, "Alış Limanı", Icons.anchor),
          const SizedBox(height: 12),
          _buildTextField(
              _unloadPortController, "Varış Limanı", Icons.flag),
        ],
        const SizedBox(height: 12),
        _buildTextField(
            _cargoInfoController, "Yük Bilgisi", Icons.inventory),
        const SizedBox(height: 14),

        // Şoför dropdown
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchDrivers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text("Hiç şoför bulunamadı");
            }

            final drivers = snapshot.data!;
            return DropdownButtonFormField<String>(
              value: _selectedDriver,
              decoration: InputDecoration(
                labelText: "Şoför Seç",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                  const BorderSide(color: Colors.blueAccent, width: 2),
                ),
              ),
              items: drivers
                  .map(
                    (d) => DropdownMenuItem<String>(
                  value: d['driverId'],
                  child: Text(d['name']),
                ),
              )
                  .toList(),
              onChanged: (val) => setState(() => _selectedDriver = val),
            );
          },
        ),
        const SizedBox(height: 22),

        // Kaydet butonu
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isCreatingJob ? null : _createJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: _isCreatingJob
                ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
                : const Text(
              "Görevi Oluştur",
              style:
              TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
