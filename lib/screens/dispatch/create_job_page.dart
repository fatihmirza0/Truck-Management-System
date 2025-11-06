import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    _scaleAnimation = Tween<double>(begin: 1, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

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

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('jobs').add({
        'loadPort': loadPort,
        'unloadPort': unloadPort,
        'cargoInfo': cargoInfo,
        'assignedTo': _selectedDriver,
        'assignedBy': 'dispatch001', // burayı giriş yapan kullanıcıyla değiştir
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
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
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
            borderSide:
            const BorderSide(color: Colors.blueAccent, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007AFF);

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
                    const Icon(Icons.assignment, color: primaryColor, size: 60),
                    const SizedBox(height: 10),
                    Text(
                      "Yeni İş Ekle",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                        _loadPortController, "Alış Limanı", Icons.anchor),
                    const SizedBox(height: 14),
                    _buildTextField(
                        _unloadPortController, "Varış Limanı", Icons.flag),
                    const SizedBox(height: 14),
                    _buildTextField(
                        _cargoInfoController, "Yük Bilgisi", Icons.inventory),
                    const SizedBox(height: 14),

                    // Şoför seç dropdown
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchDrivers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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
                              borderSide:
                              BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          items: drivers
                              .map((d) => DropdownMenuItem<String>(
                            value: d['driverId'],
                            child: Text(d['name']),
                          ))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _selectedDriver = val);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    // Kaydet butonu
                    GestureDetector(
                      onTap: _isLoading ? null : _createJob,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlue],
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
                          "Görevi Oluştur",
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
      ),
    );
  }
}
