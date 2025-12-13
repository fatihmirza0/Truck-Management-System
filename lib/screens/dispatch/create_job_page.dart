import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> with TickerProviderStateMixin {
  final TextEditingController _loadPortController = TextEditingController();
  final TextEditingController _unloadPortController = TextEditingController();
  final TextEditingController _cargoInfoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedDriverUid;
  Map<String, dynamic>? _selectedDriver;
  bool _isCreatingJob = false;
  bool _showDriverPanel = false;
  String _searchQuery = '';

  String? _dispatchUid;
  bool _isLoadingDispatch = true;

  late AnimationController _panelController;
  late Animation<double> _panelAnimation;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  static const Color primary = Color(0xFF1E293B);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentLight = Color(0xFFEFF6FF);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadDispatchUid();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _loadPortController.dispose();
    _unloadPortController.dispose();
    _cargoInfoController.dispose();
    _searchController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  Future<void> _loadDispatchUid() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _dispatchUid = user.uid;
      }
    } finally {
      if (mounted) setState(() => _isLoadingDispatch = false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDrivers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'driver')
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return {
        'uid': doc.id,
        'name': d['name'] ?? '-',
        'plate': d['plateNumber'] ?? '-',
        'jobStatus': d['jobStatus'] ?? 'available',
      };
    }).toList();
  }

  Future<void> _createJob() async {
    final loadPort = _loadPortController.text.trim();
    final unloadPort = _unloadPortController.text.trim();
    final cargoInfo = _cargoInfoController.text.trim();

    if (loadPort.isEmpty || unloadPort.isEmpty || cargoInfo.isEmpty || _selectedDriverUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Lütfen tüm alanları doldurun ve şoför seçin"),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
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
      await FirebaseFirestore.instance.collection('jobs').add({
        'loadPort': loadPort,
        'unloadPort': unloadPort,
        'cargoInfo': cargoInfo,
        'assignedToUid': _selectedDriverUid,
        'assignedByUid': _dispatchUid,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(_selectedDriverUid)
          .update({'jobStatus': 'busy'});

      _loadPortController.clear();
      _unloadPortController.clear();
      _cargoInfoController.clear();
      setState(() {
        _selectedDriverUid = null;
        _selectedDriver = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("✓ Görev başarıyla oluşturuldu"),
          backgroundColor: success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      setState(() => _isCreatingJob = false);
    }
  }

  void _openDriverPanel() {
    setState(() => _showDriverPanel = true);
    _panelController.forward();
  }

  void _closeDriverPanel() {
    _panelController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showDriverPanel = false;
          _searchQuery = '';
          _searchController.clear();
        });
      }
    });
  }

  void _selectDriver(Map<String, dynamic> driver) {
    setState(() {
      _selectedDriverUid = driver['uid'];
      _selectedDriver = driver;
    });
    _closeDriverPanel();
  }

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: textSecondary, size: 20),
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
    );
  }

  Widget _buildDriverSelectionCard() {
    return GestureDetector(
      onTap: _openDriverPanel,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedDriver == null ? cardBg : accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDriver == null ? border : accent,
            width: _selectedDriver == null ? 1 : 2,
          ),
        ),
        child: _selectedDriver == null
            ? Row(
          children: const [
            Icon(Icons.person_add_outlined, color: Color(0xFF1E3A5F), size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Şoför Seç",
                style: TextStyle(
                  fontSize: 15,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: textSecondary, size: 16),
          ],
        )
            : Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedDriver!['name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedDriver!['plate'],
                    style: const TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverPanel() {
    return Stack(
      children: [
        // Backdrop
        GestureDetector(
          onTap: _closeDriverPanel,
          child: AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.black.withOpacity(0.4 * _panelAnimation.value),
              );
            },
          ),
        ),

        // Panel
        Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _panelAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  0,
                  isDesktop
                      ? (1 - _panelAnimation.value) * 50
                      : (1 - _panelAnimation.value) * 500,
                ),
                child: Opacity(
                  opacity: _panelAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              height: isDesktop ? 500 : MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: isDesktop
                    ? BorderRadius.circular(16)
                    : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isDesktop ? 16 : 24),
                        topRight:  Radius.circular(isDesktop ? 16 : 24),
                      ),
                      border: const Border(bottom: BorderSide(color: border)),
                    ),
                    child: Column(
                      children: [
                        if (!isDesktop)
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_shipping, color: Color(0xFF1E3A5F), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Şoför Seç",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _closeDriverPanel,
                              icon: const Icon(Icons.close, size: 22),
                              color: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: "Ara...",
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search, color: textSecondary, size: 20),
                            filled: true,
                            fillColor: bg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Driver List
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchDrivers(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final drivers = snap.data!.where((d) {
                          if (_searchQuery.isEmpty) return true;
                          return d['name'].toString().toLowerCase().contains(_searchQuery) ||
                              d['plate'].toString().toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (drivers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.search_off, size: 48, color: textSecondary),
                                SizedBox(height: 12),
                                Text(
                                  "Şoför bulunamadı",
                                  style: TextStyle(fontSize: 15, color: textSecondary),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: drivers.length,
                          itemBuilder: (context, i) {
                            final driver = drivers[i];
                            final busy = driver['jobStatus'] == 'busy';
                            final isSelected = driver['uid'] == _selectedDriverUid;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? accentLight : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? accent : border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: busy ? null : () => _selectDriver(driver),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: busy ? Colors.grey.shade300 : accent,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.local_shipping_outlined,
                                            color: busy ? Colors.grey.shade600 : Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                driver['name'],
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: busy ? textSecondary : textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                driver['plate'],
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: busy
                                                ? warning.withOpacity(0.1)
                                                : success.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: busy ? warning : success,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                busy ? "Meşgul" : "Müsait",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: busy ? warning : success,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 8),
                                            child: Icon(
                                              Icons.check_circle,
                                              color: accent,
                                              size: 22,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDispatch) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Main Content
        Container(
          color: bg,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E3A5F), primary.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.assignment_add,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Yeni İş Oluştur",
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Sevkiyat detaylarını girin",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Form Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Sevkiyat Bilgileri",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _loadPortController,
                                    decoration: _input("Alış Limanı", Icons.anchor),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _unloadPortController,
                                    decoration: _input("Varış Limanı", Icons.flag),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            TextField(
                              controller: _loadPortController,
                              decoration: _input("Alış Limanı", Icons.anchor),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _unloadPortController,
                              decoration: _input("Varış Limanı", Icons.flag),
                            ),
                          ],

                          const SizedBox(height: 12),

                          TextField(
                            controller: _cargoInfoController,
                            maxLines: 2,
                            decoration: _input("Yük Bilgisi", Icons.inventory_2_outlined),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "Şoför Ataması",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildDriverSelectionCard(),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isCreatingJob ? null : _createJob,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF1E3A5F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isCreatingJob
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                "Görevi Oluştur",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
        ),

        // Driver Selection Panel Overlay
        if (_showDriverPanel) _buildDriverPanel(),
      ],
    );
  }
}