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

  String? _selectedDriverUid;
  bool _isCreatingJob = false;

  /// Giriş yapan dispatch'in UID'si
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
    _loadPortController.dispose();
    _unloadPortController.dispose();
    _cargoInfoController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 🔹 Dispatch UID yükle
  // ---------------------------------------------------------------------------
  Future<void> _loadDispatchUid() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        _dispatchUid = user.uid;
      }
    } catch (_) {
      // sessiz geç
    } finally {
      if (mounted) setState(() => _isLoadingDispatch = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 Şoförleri UID olarak yükle
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'name': data['name'] ?? 'Bilinmeyen',
        'plate': data['plateNumber'] ?? '-',
        'jobStatus': data['jobStatus'] ?? 'available',
      };
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 🔹 İş oluştur
  // ---------------------------------------------------------------------------
  Future<void> _createJob() async {
    final loadPort = _loadPortController.text.trim();
    final unloadPort = _unloadPortController.text.trim();
    final cargoInfo = _cargoInfoController.text.trim();

    if (loadPort.isEmpty ||
        unloadPort.isEmpty ||
        cargoInfo.isEmpty ||
        _selectedDriverUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurun")),
      );
      return;
    }

    if (_dispatchUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dispatch UID okunamadı")),
      );
      return;
    }

    setState(() => _isCreatingJob = true);

    try {
      /// 🔥 1) Jobs koleksiyonuna iş ekle
      await FirebaseFirestore.instance.collection('jobs').add({
        'loadPort': loadPort,
        'unloadPort': unloadPort,
        'cargoInfo': cargoInfo,
        'assignedToUid': _selectedDriverUid, // UID
        'assignedByUid': _dispatchUid, // Dispatch UID
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      /// 🔥 2) Şoförün durumunu BUSY yap
      await FirebaseFirestore.instance
          .collection("users")
          .doc(_selectedDriverUid)
          .update({
        'jobStatus': 'busy',
      });

      /// Formu temizle
      _loadPortController.clear();
      _unloadPortController.clear();
      _cargoInfoController.clear();
      setState(() => _selectedDriverUid = null);

      await _animationController.forward();
      await Future.delayed(const Duration(milliseconds: 120));
      await _animationController.reverse();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.blueAccent,
          content: Text("Görev başarıyla oluşturuldu"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isCreatingJob = false);
    }
  }

  // ---------------------------------------------------------------------------
  // TEXT FIELD
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
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007AFF);

    if (_isLoadingDispatch) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _form(primaryColor),
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
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
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
              ),              const SizedBox(width: 28),
              Expanded(
                flex: 5,
                child: Container(
                  height: 400,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                  ),
                  child: _form(primaryColor, isDesktop: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORM (Ortak)
  // ---------------------------------------------------------------------------
  Widget _form(Color primaryColor, {bool isDesktop = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isDesktop)
          const Icon(Icons.assignment, size: 40, color: Colors.blue),
        Text(
          "Yeni İş Ekle",
          style: TextStyle(
            fontSize: isDesktop ? 22 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),

        // Limanlar
        if (isDesktop)
          Row(
            children: [
              Expanded(
                child:
                _buildTextField(_loadPortController, "Alış Limanı", Icons.anchor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                    _unloadPortController, "Varış Limanı", Icons.flag),
              ),
            ],
          )
        else ...[
          _buildTextField(_loadPortController, "Alış Limanı", Icons.anchor),
          const SizedBox(height: 12),
          _buildTextField(_unloadPortController, "Varış Limanı", Icons.flag),
        ],

        const SizedBox(height: 12),
        _buildTextField(
            _cargoInfoController, "Yük Bilgisi", Icons.inventory_2_outlined),

        const SizedBox(height: 14),

        // Şoför seçimi
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchDrivers(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final drivers = snap.data!;
            if (drivers.isEmpty) {
              return const Text("Hiç şoför bulunamadı.");
            }

            return DropdownButtonFormField<String>(
              value: _selectedDriverUid,
              decoration: InputDecoration(
                labelText: "Şoför Seç",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: drivers.map((d) {
                final isBusy = d['jobStatus'] == 'busy';

                return DropdownMenuItem<String>(
                  value: d['uid'],   // ❗ her zaman String
                  enabled: !isBusy,  // ❗ meşgulse seçilemez
                  child: Row(
                    children: [
                      Text(d['name']),
                      const SizedBox(width: 6),
                      Text("(${d['plate']})", style: const TextStyle(color: Colors.grey)),
                      if (isBusy)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Text(
                            "[meşgul]",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedDriverUid = val),
            );
          },
        ),

        const SizedBox(height: 22),

        // Görev oluştur
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isCreatingJob ? null : _createJob,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: _isCreatingJob
                ? const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2)
                : const Text(
              "Görevi Oluştur",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
