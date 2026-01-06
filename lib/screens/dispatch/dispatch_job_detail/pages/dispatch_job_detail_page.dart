import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lojistik/services/firestore_Service.dart';
import '../widgets/job_detail_widgets.dart';

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
    _initializeControllers();
    _loadDriversAndVehicles();
  }

  void _initializeControllers() {
    _cargoTypeCtrl = TextEditingController(
      text: widget.data['cargo']?['type'] ?? '',
    );
    _cargoDescCtrl = TextEditingController(
      text: widget.data['cargo']?['description'] ?? '',
    );
    _cargoWeightCtrl = TextEditingController(
      text: widget.data['cargo']?['weightKg']?.toString() ?? '',
    );
    _loadPortCtrl = TextEditingController(
      text: widget.data['route']?['loadPort'] ?? '',
    );
    _unloadPortCtrl = TextEditingController(
      text: widget.data['route']?['unloadPort'] ?? '',
    );
    _referenceNoCtrl = TextEditingController(
      text: widget.data['referenceNo'] ?? '',
    );

    _selectedDriverId = widget.data['driverId'];
    _selectedVehicleId = widget.data['vehicleId'];
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
      await _loadDrivers();
      await _loadVehicles();
      _filterVehiclesByDriver(_selectedDriverId);
    } catch (e) {
      debugPrint('Load drivers/vehicles error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadDrivers() async {
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
  }

  Future<void> _loadVehicles() async {
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

      if (currentVehicle.isEmpty ||
          currentVehicle['assignedDriverId'] != driverId) {
        _selectedVehicleId = null;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool get _canEdit {
    final status = widget.data['status'];
    return status == FirestoreService.statusPending ||
        status == FirestoreService.statusRejected;
  }

  Future<void> _saveChanges() async {
    if (!_validateForm()) return;

    setState(() => _saving = true);

    try {
      await _updateJob();
      await _addJobLog();
      _showSuccessMessage();

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _validateForm() {
    if (_selectedDriverId == null || _selectedDriverId!.isEmpty) {
      _showSnackBar('Lütfen şoför seçiniz');
      return false;
    }

    if (_selectedVehicleId == null || _selectedVehicleId!.isEmpty) {
      _showSnackBar('Lütfen araç seçiniz');
      return false;
    }

    if (_cargoTypeCtrl.text.isEmpty ||
        _loadPortCtrl.text.isEmpty ||
        _unloadPortCtrl.text.isEmpty) {
      _showSnackBar('Lütfen zorunlu alanları doldurunuz');
      return false;
    }

    final weight = double.tryParse(_cargoWeightCtrl.text);
    if (weight == null || weight <= 0) {
      _showSnackBar('Lütfen geçerli bir ağırlık giriniz');
      return false;
    }

    return true;
  }

  Future<void> _updateJob() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }

    final updateData = {
      'driverId': _selectedDriverId,
      'vehicleId': _selectedVehicleId,
      'status': FirestoreService.statusPending,
      'rejectionReason': null,
      'route': {
        'loadPort': _loadPortCtrl.text.trim(),
        'unloadPort': _unloadPortCtrl.text.trim(),
      },
      'cargo': {
        'type': _cargoTypeCtrl.text.trim(),
        'description': _cargoDescCtrl.text.trim(),
        'weightKg': double.parse(_cargoWeightCtrl.text),
      },
      'timestamps.reviewedAt': null,
    };

    await FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .update(updateData);
  }

  Future<void> _addJobLog() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

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
        content: const Text(
          'Bu işi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => _confirmDelete(),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    Navigator.pop(context);
    try {
      await FirestoreService.deleteJob(widget.jobId);
      _showSuccessMessage('İş silindi');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showErrorMessage(e.toString());
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSuccessMessage([String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? 'İş güncellendi ve onay için gönderildi'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hata: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? FirestoreService.statusPending;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(status),
      body: _loading
          ? _buildLoadingIndicator()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _editing
            ? _buildEditMode()
            : _buildViewMode(status),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String status) {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.description_outlined, size: 22),
          const SizedBox(width: 12),
          const Text(
            "İş Detayları",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          StatusChip(status: status),
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
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
      ),
    );
  }

  Widget _buildViewMode(String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JobReferenceCard(
          referenceNo: widget.data['referenceNo'] ?? 'REF-XXX',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                title: 'Şoför',
                value: widget.driverName ?? 'Bilinmiyor',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoCard(
                title: 'Araç',
                value: widget.vehiclePlate ?? 'Bilinmiyor',
                icon: Icons.local_shipping_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Güzergah',
          value: '${widget.data['route']?['loadPort'] ?? '-'} → '
              '${widget.data['route']?['unloadPort'] ?? '-'}',
          icon: Icons.route_outlined,
        ),
        const SizedBox(height: 12),
        CargoInfoCard(cargo: widget.data['cargo']),
        if (status == FirestoreService.statusRejected &&
            widget.data['rejectionReason'] != null) ...[
          const SizedBox(height: 12),
          RejectionReasonCard(reason: widget.data['rejectionReason']),
        ],
        if (status == 'completed' &&
            widget.data['documents'] != null &&
            (widget.data['documents'] as List).isNotEmpty) ...[
          const SizedBox(height: 12),
          DocumentsCard(
            documents: widget.data['documents'] as List,
            referenceNo: widget.data['referenceNo'] ?? 'REF-XXX',
            showDebug: false,
          ),
        ],
        if (_canEdit) ...[
          const SizedBox(height: 20),
          _buildEditButton(),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildEditButton() {
    return ElevatedButton.icon(
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
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JobReferenceCard(
          referenceNo: widget.data['referenceNo'] ?? 'REF-XXX',
        ),
        const SizedBox(height: 16),
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
              DriverDropdown(
                drivers: _drivers,
                selectedDriverId: _selectedDriverId,
                onChanged: (value) {
                  setState(() {
                    _selectedDriverId = value;
                    _selectedVehicleId = null;
                    _filterVehiclesByDriver(value);
                  });
                },
              ),
              const SizedBox(height: 16),
              VehicleDropdown(
                vehicles: _filteredVehicles,
                selectedVehicleId: _selectedVehicleId,
                selectedDriverId: _selectedDriverId,
                onChanged: (value) => setState(() => _selectedVehicleId = value),
              ),
              const SizedBox(height: 16),
              JobFormTextField(
                controller: _cargoTypeCtrl,
                label: 'Yük Türü *',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 16),
              JobFormTextField(
                controller: _cargoDescCtrl,
                label: 'Yük Açıklaması',
                icon: Icons.description_outlined,
                maxLines: 3,
                hintText: 'Yük açıklaması...',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: JobFormTextField(
                      controller: _cargoWeightCtrl,
                      label: 'Ağırlık (kg) *',
                      icon: Icons.scale_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: JobFormTextField(
                      controller: _referenceNoCtrl,
                      label: 'Referans No',
                      icon: Icons.numbers_outlined,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: JobFormTextField(
                      controller: _loadPortCtrl,
                      label: 'Yükleme Noktası *',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: JobFormTextField(
                      controller: _unloadPortCtrl,
                      label: 'Varış Noktası *',
                      icon: Icons.flag_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormButtons(),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFormButtons() {
    return Row(
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
    );
  }
}