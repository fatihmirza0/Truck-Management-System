import 'package:flutter/material.dart';
import '../../../../services/firestore_service.dart';
import '../../../../config/app_theme.dart';

class VehicleDetailPage extends StatefulWidget {
  final Map<String, dynamic>? vehicle;

  const VehicleDetailPage({super.key, this.vehicle});

  @override
  State<VehicleDetailPage> createState() => _VehicleDetailPageState();
}

class _VehicleDetailPageState extends State<VehicleDetailPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _plateController;
  late TextEditingController _typeController;
  late TextEditingController _ownershipController;
  late TextEditingController _insurancePolicyController;
  late TextEditingController _currentKmController;
  late TextEditingController _lastMaintenanceKmController;

  String _status = 'active';
  String? _assignedDriverId;
  DateTime? _insuranceExpiryDate;
  DateTime? _lastMaintenanceDate;

  List<Map<String, dynamic>> _drivers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _plateController = TextEditingController(text: v?['plate']);
    _typeController = TextEditingController(text: v?['type']);
    _ownershipController = TextEditingController(text: v?['ownership']);
    _insurancePolicyController = TextEditingController(text: v?['insurancePolicyNumber']);
    _currentKmController = TextEditingController(text: v?['currentKm']?.toString());
    _lastMaintenanceKmController = TextEditingController(text: v?['lastMaintenanceKm']?.toString());
    
    _status = v?['status'] ?? 'active';
    _assignedDriverId = v?['assignedDriverId'];
    
    if (v?['insuranceExpiryDate'] != null) {
      _insuranceExpiryDate = (v!['insuranceExpiryDate'] as dynamic).toDate();
    }
    if (v?['lastMaintenanceDate'] != null) {
      _lastMaintenanceDate = (v!['lastMaintenanceDate'] as dynamic).toDate();
    }

    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    try {
      final drivers = await FirestoreService.fetchDrivers();
      if (mounted) {
        setState(() {
          _drivers = drivers;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Şoför listesi alınamadı: $e")),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final double? currentKm = double.tryParse(_currentKmController.text);
      final double? lastMaintenanceKm = double.tryParse(_lastMaintenanceKmController.text);

      if (widget.vehicle == null) {
        // Create
        await FirestoreService.createVehicle(
          plate: _plateController.text,
          type: _typeController.text,
          ownership: _ownershipController.text,
          assignedDriverId: _assignedDriverId,
          status: _status,
          insurancePolicyNumber: _insurancePolicyController.text,
          insuranceExpiryDate: _insuranceExpiryDate,
          lastMaintenanceDate: _lastMaintenanceDate,
          lastMaintenanceKm: lastMaintenanceKm,
          currentKm: currentKm,
        );
      } else {
        // Update
        await FirestoreService.updateVehicle(
          vehicleId: widget.vehicle!['vehicleId'],
          plate: _plateController.text,
          type: _typeController.text,
          ownership: _ownershipController.text,
          assignedDriverId: _assignedDriverId,
          status: _status,
          insurancePolicyNumber: _insurancePolicyController.text,
          insuranceExpiryDate: _insuranceExpiryDate,
          lastMaintenanceDate: _lastMaintenanceDate,
          lastMaintenanceKm: lastMaintenanceKm,
          currentKm: currentKm,
        );
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to trigger refresh
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kayıt başarılı"),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Hata: $e"),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              widget.vehicle == null ? "Yeni Araç" : "Araç Detayı",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.textPrimary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 24),
                  _buildSectionTitle("Temel Bilgiler", Icons.info_outline_rounded),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Plaka", _plateController, required: true, icon: Icons.tag)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Tip", _typeController, required: true, icon: Icons.local_shipping_outlined)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField("Mülkiyet (Özmal / Kiralık)", _ownershipController, required: true, icon: Icons.business),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle("Durum ve Atama", Icons.assignment_ind_outlined),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStatusDropdown(),
                        const SizedBox(height: 16),
                        _buildDriverDropdown(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle("Bakım ve Sigorta Detayları", Icons.build_circle_outlined),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField("Sigorta Poliçe No", _insurancePolicyController, icon: Icons.policy_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePicker(
                                "Sigorta Bitiş",
                                _insuranceExpiryDate,
                                (date) => setState(() => _insuranceExpiryDate = date),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDatePicker(
                                "Son Bakım Tarihi",
                                _lastMaintenanceDate,
                                (date) => setState(() => _lastMaintenanceDate = date),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField("Son Bakım KM", _lastMaintenanceKmController, isNumber: true, icon: Icons.speed)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Güncel KM", _currentKmController, isNumber: true, icon: Icons.speed)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100), // Bottom padding for FAB/Button
                ],
              ),
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Değişiklikleri Kaydet",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ),
        if (_isSaving)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    if (widget.vehicle == null) return const SizedBox.shrink();

    return Center(
      child: Column(
        children: [
          Hero(
            tag: 'vehicle_icon_${widget.vehicle!['vehicleId']}',
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 2),
              ),
              child: const Icon(Icons.local_shipping, size: 40, color: AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.vehicle!['plate'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.vehicle!['type'],
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool required = false, bool isNumber = false, IconData? icon}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary, size: 20) : null,
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required ? (val) => val == null || val.isEmpty ? "$label gerekli" : null : null,
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: _status,
      decoration: InputDecoration(
        labelText: "Durum",
        prefixIcon: const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: const [
        DropdownMenuItem(value: "active", child: Text("Aktif", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
        DropdownMenuItem(value: "maintenance", child: Text("Bakımda", style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold))),
        DropdownMenuItem(value: "out_of_service", child: Text("Servis Dışı", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold))),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _status = val);
      },
    );
  }

  Widget _buildDriverDropdown() {
    return DropdownButtonFormField<String>(
      value: _assignedDriverId,
      decoration: InputDecoration(
        labelText: "Atanan Sürücü",
        prefixIcon: const Icon(Icons.person_pin_circle_outlined, color: AppTheme.textSecondary, size: 20),
        filled: true,
        fillColor: AppTheme.backgroundColor,
         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text("Atanmadı")),
        ..._drivers.map((d) => DropdownMenuItem(
          value: d['uid'], 
          child: Text(d['name'] ?? "İsimsiz"),
        )),
      ],
      onChanged: (val) {
        setState(() => _assignedDriverId = val);
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                primaryColor: AppTheme.primaryColor,
                colorScheme: const ColorScheme.light(primary: AppTheme.primaryColor),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onSelect(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  date != null ? "${date.day}/${date.month}/${date.year}" : "Seçiniz",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
