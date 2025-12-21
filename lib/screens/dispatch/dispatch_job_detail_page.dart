import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lojistik/services/firestore_Service.dart';

class DispatchJobDetailPage extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> data;
  final String? driverName;
  final String? vehiclePlate;

  const DispatchJobDetailPage({
    super.key,
    required this.jobId,
    required this.data,
    this.driverName,
    this.vehiclePlate,
  });

  @override
  State<DispatchJobDetailPage> createState() => _DispatchJobDetailPageState();
}

class _DispatchJobDetailPageState extends State<DispatchJobDetailPage> {
  late bool _editing = false;
  bool _saving = false;
  bool _loading = true;

  // Form controllers
  late TextEditingController _cargoTypeCtrl;
  late TextEditingController _cargoDescCtrl;
  late TextEditingController _cargoWeightCtrl;
  late TextEditingController _loadPortCtrl;
  late TextEditingController _unloadPortCtrl;
  late TextEditingController _referenceNoCtrl;

  // Dropdown values
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _vehicles = [];
  String? _selectedDriverId;
  String? _selectedVehicleId;

  // Şoföre göre filtreli araçlar
  List<Map<String, dynamic>> _filteredVehicles = [];

  @override
  void initState() {
    super.initState();

    // Initialize form controllers with existing data
    _cargoTypeCtrl = TextEditingController(text: widget.data['cargo']?['type'] ?? '');
    _cargoDescCtrl = TextEditingController(text: widget.data['cargo']?['description'] ?? '');
    _cargoWeightCtrl = TextEditingController(text: widget.data['cargo']?['weightKg']?.toString() ?? '');
    _loadPortCtrl = TextEditingController(text: widget.data['route']?['loadPort'] ?? '');
    _unloadPortCtrl = TextEditingController(text: widget.data['route']?['unloadPort'] ?? '');
    _referenceNoCtrl = TextEditingController(text: widget.data['referenceNo'] ?? '');

    _selectedDriverId = widget.data['driverId'];
    _selectedVehicleId = widget.data['vehicleId'];

    _loadDriversAndVehicles();
  }

  @override
  void dispose() {
    _cargoTypeCtrl.dispose();
    _cargoDescCtrl.dispose();
    _cargoWeightCtrl.dispose();
    _loadPortCtrl.dispose();
    _unloadPortCtrl.dispose();
    _referenceNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDriversAndVehicles() async {
    try {
      // Load active drivers
      final driversSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('softDeleted', isEqualTo: false)
          .where('isActive', isEqualTo: true)
          .get();

      _drivers = driversSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
        };
      }).toList();

      // Load all active vehicles
      final vehiclesSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('isActive', isEqualTo: true)
          .get();

      _vehicles = vehiclesSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'vehicleId': doc.id,
          'plate': data['plate'] ?? '',
          'type': data['type'] ?? '',
          'assignedDriverId': data['assignedDriverId'],
        };
      }).toList();

      // Başlangıçta seçili şoförün araçlarını filtrele
      _filterVehiclesByDriver(_selectedDriverId);

    } catch (e) {
      debugPrint('Load drivers/vehicles error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _filterVehiclesByDriver(String? driverId) {
    if (driverId == null) {
      _filteredVehicles = [];
    } else {
      _filteredVehicles = _vehicles.where((vehicle) {
        return vehicle['assignedDriverId'] == driverId;
      }).toList();
    }

    // Eğer mevcut seçili araç şoföre ait değilse, araç seçimini sıfırla
    if (_selectedVehicleId != null) {
      final currentVehicle = _vehicles.firstWhere(
            (v) => v['vehicleId'] == _selectedVehicleId,
        orElse: () => {},
      );

      if (currentVehicle.isEmpty || currentVehicle['assignedDriverId'] != driverId) {
        _selectedVehicleId = null;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool get _canEdit {
    final status = widget.data['status'];
    // Sadece pending veya rejected durumunda düzenleyebilir
    return status == FirestoreService.statusPending ||
        status == FirestoreService.statusRejected;
  }

  Future<void> _saveChanges() async {
    // Validation
    if (_selectedDriverId == null || _selectedDriverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen şoför seçiniz')),
      );
      return;
    }

    if (_selectedVehicleId == null || _selectedVehicleId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen araç seçiniz')),
      );
      return;
    }

    if (_cargoTypeCtrl.text.isEmpty || _loadPortCtrl.text.isEmpty || _unloadPortCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen zorunlu alanları doldurunuz')),
      );
      return;
    }

    final weight = double.tryParse(_cargoWeightCtrl.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir ağırlık giriniz')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      final updateData = {
        'driverId': _selectedDriverId,
        'vehicleId': _selectedVehicleId,
        // REFERENCE NO DEĞİŞTİRİLEMEZ! (sabit kalır)
        'status': FirestoreService.statusPending, // Her düzenlemede pending'e çek
        'rejectionReason': null, // Red sebebini temizle
        'route': {
          'loadPort': _loadPortCtrl.text.trim(),
          'unloadPort': _unloadPortCtrl.text.trim(),
        },
        'cargo': {
          'type': _cargoTypeCtrl.text.trim(),
          'description': _cargoDescCtrl.text.trim(),
          'weightKg': weight,
        },
        'timestamps.reviewedAt': null, // Review tarihini sıfırla
      };

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update(updateData);

      // Add edit log
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .collection('logs')
          .add({
        'action': 'updated',
        'performedBy': currentUid,
        'performedAt': FieldValue.serverTimestamp(),
        'note': 'İş bilgileri güncellendi ve onay için gönderildi',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('İş güncellendi ve onay için gönderildi'),
          backgroundColor: Colors.green,
        ),
      );

      // Sayfayı kapat ve ana sayfaya dön
      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _deleteJob() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('İşi Sil'),
          ],
        ),
        content: const Text('Bu işi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirestoreService.deleteJob(widget.jobId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('İş silindi'),
                    backgroundColor: Colors.green,
                  ),
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hata: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final statusColor = FirestoreService.getStatusColor(status);
    final statusText = FirestoreService.getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Şoför *',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedDriverId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              hint: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Şoför seçin...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              items: _drivers.map((driver) {
                return DropdownMenuItem<String>(
                  value: driver['uid'],
                  child: Text(driver['name'] ?? ''),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDriverId = value;
                  _selectedVehicleId = null; // Şoför değişince araç seçimini sıfırla
                  _filterVehiclesByDriver(value);
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Araç *',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedVehicleId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              hint: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  if (_selectedDriverId == null)
                    Text('Önce şoför seçin...', style: TextStyle(color: Colors.grey[600]))
                  else if (_filteredVehicles.isEmpty)
                    Text('Bu şoföre ait araç yok', style: TextStyle(color: Colors.orange[600]))
                  else
                    Text('Araç seçin...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              items: _filteredVehicles.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle['vehicleId'],
                  child: Text('${vehicle['plate']} (${vehicle['type']})'),
                );
              }).toList(),
              onChanged: (_selectedDriverId == null || _filteredVehicles.isEmpty)
                  ? null
                  : (value) {
                setState(() {
                  _selectedVehicleId = value;
                });
              },
            ),
          ),
        ),
        if (_selectedDriverId != null && _filteredVehicles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Seçili şoföre ait aktif araç bulunmuyor',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange[600],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? FirestoreService.statusPending;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.description_outlined, size: 22),
            const SizedBox(width: 12),
            const Text(
              "İş Detayları",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusChip(status),
          ],
        ),
        actions: [
          if (_canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Düzenle',
            ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteJob,
              tooltip: 'Sil',
            ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İş Referans (DEĞİŞTİRİLEMEZ)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      size: 22,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.data['referenceNo'] ?? 'REF-XXX',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A5F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İş Referans Numarası (Değiştirilemez)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (!_editing) ...[
              // GÖRÜNÜM MODU
              // Şoför ve Araç Bilgileri
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'Şoför',
                      widget.driverName ?? 'Bilinmiyor',
                      Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Araç',
                      widget.vehiclePlate ?? 'Bilinmiyor',
                      Icons.local_shipping_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Güzergah
              _buildInfoCard(
                'Güzergah',
                '${widget.data['route']?['loadPort'] ?? '-'} → ${widget.data['route']?['unloadPort'] ?? '-'}',
                Icons.route_outlined,
              ),
              const SizedBox(height: 12),

              // Yük Bilgileri
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Yük Bilgileri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Yük Türü',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.data['cargo']?['type'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ağırlık',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.data['cargo']?['weightKg'] ?? '-'} kg',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Açıklama',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.data['cargo']?['description'] ?? '-',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Reddetme Sebebi (sadece rejected durumunda)
              if (status == FirestoreService.statusRejected &&
                  widget.data['rejectionReason'] != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reddetme Sebebi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.data['rejectionReason'] ?? '',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Düzenleme Butonu (sadece pending veya rejected durumunda)
              if (_canEdit)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _editing = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'İşi Düzenle ve Tekrar Gönder',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ] else ...[
              // DÜZENLEME MODU
              const Text(
                'İş Bilgilerini Düzenle',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Şoför Seçimi
                    _buildDriverDropdown(),
                    const SizedBox(height: 16),

                    // Araç Seçimi
                    _buildVehicleDropdown(),
                    const SizedBox(height: 16),

                    // Yük Türü
                    _buildTextField(_cargoTypeCtrl, 'Yük Türü *', Icons.inventory_2_outlined),
                    const SizedBox(height: 16),

                    // Yük Açıklaması
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yük Açıklaması',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: _cargoDescCtrl,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Yük açıklaması...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_cargoWeightCtrl, 'Ağırlık (kg) *', Icons.scale_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _referenceNoCtrl,
                            'Referans No',
                            Icons.numbers_outlined,
                            enabled: false, // DEĞİŞTİRİLEMEZ!
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Yükleme ve Varış Noktaları
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(_loadPortCtrl, 'Yükleme Noktası *', Icons.location_on_outlined),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(_unloadPortCtrl, 'Varış Noktası *', Icons.flag_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Butonlar
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => setState(() => _editing = false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('İptal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_outlined, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Kaydet ve Gönder',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}