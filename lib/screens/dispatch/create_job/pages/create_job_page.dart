// 📁 lib/pages/create_job_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lojistik/services/firestore_Service.dart';
import 'package:lojistik/utils/route_utils.dart';
import '../widgets/driver_selection_card.dart';
import '../widgets/vehicle_selection_card.dart';
import '../widgets/driver_selection_panel.dart';
import '../widgets/vehicle_selection_panel.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> with TickerProviderStateMixin {
  final _loadPortController = TextEditingController();
  final _unloadPortController = TextEditingController();
  final _cargoTypeController = TextEditingController();
  final _cargoDescriptionController = TextEditingController();
  final _cargoWeightController = TextEditingController();
  final _driverSearchController = TextEditingController();
  final _vehicleSearchController = TextEditingController();

  String? _selectedDriverUid;
  Map<String, dynamic>? _selectedDriver;
  String? _selectedVehicleId;
  Map<String, dynamic>? _selectedVehicle;
  bool _isCreatingJob = false;
  bool _showDriverPanel = false;
  bool _showVehiclePanel = false;
  String _driverSearchQuery = '';
  String _vehicleSearchQuery = '';

  late AnimationController _driverPanelController;
  late Animation<double> _driverPanelAnimation;
  late AnimationController _vehiclePanelController;
  late Animation<double> _vehiclePanelAnimation;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  // 🎨 Color Palette
  static const Color primary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _driverPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _driverPanelAnimation = CurvedAnimation(
      parent: _driverPanelController,
      curve: Curves.easeOutCubic,
    );
    _vehiclePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _vehiclePanelAnimation = CurvedAnimation(
      parent: _vehiclePanelController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _loadPortController.dispose();
    _unloadPortController.dispose();
    _cargoTypeController.dispose();
    _cargoDescriptionController.dispose();
    _cargoWeightController.dispose();
    _driverSearchController.dispose();
    _vehicleSearchController.dispose();
    _driverPanelController.dispose();
    _vehiclePanelController.dispose();
    super.dispose();
  }

  Future<void> _createJob() async {
    final loadPort = _loadPortController.text.trim();
    final unloadPort = _unloadPortController.text.trim();
    final cargoType = _cargoTypeController.text.trim();
    final cargoDescription = _cargoDescriptionController.text.trim();
    final cargoWeightStr = _cargoWeightController.text.trim();

    if (loadPort.isEmpty || unloadPort.isEmpty || cargoType.isEmpty ||
        cargoDescription.isEmpty || cargoWeightStr.isEmpty ||
        _selectedDriverUid == null || _selectedVehicleId == null) {
      _showSnackBar("Lütfen tüm alanları doldurun ve şoför/araç seçin", isError: true);
      return;
    }

    final cargoWeight = double.tryParse(cargoWeightStr);
    if (cargoWeight == null || cargoWeight <= 0) {
      _showSnackBar("Lütfen geçerli bir ağırlık girin", isError: true);
      return;
    }

    setState(() => _isCreatingJob = true);

    try {
      final driverStatus = await FirestoreService.getDriverStatus(_selectedDriverUid!);
      if (driverStatus == 'busy') {
        _showSnackBar("Bu şoför zaten aktif bir görevde.", isError: true);
        setState(() => _isCreatingJob = false);
        return;
      }

      final loadCoords = await RouteUtils.geocode(loadPort);
      final unloadCoords = await RouteUtils.geocode(unloadPort);

      if (loadCoords == null || unloadCoords == null) {
        _showSnackBar("Adresler koordinata çevrilemedi.", isError: true);
        setState(() => _isCreatingJob = false);
        return;
      }

      double distanceKm = await RouteUtils.getRouteKm(
        loadCoords['lat']!, loadCoords['lng']!,
        unloadCoords['lat']!, unloadCoords['lng']!,
      );

      if (distanceKm == 0) {
        distanceKm = RouteUtils.haversineKm(
          loadCoords['lat']!, loadCoords['lng']!,
          unloadCoords['lat']!, unloadCoords['lng']!,
        );
      }

      await FirestoreService.createJob(
        driverId: _selectedDriverUid!,
        vehicleId: _selectedVehicleId!,
        loadPort: loadPort,
        unloadPort: unloadPort,
        cargoType: cargoType,
        cargoDescription: cargoDescription,
        cargoWeightKg: cargoWeight,
        distanceKm: distanceKm,
      );

      await FirestoreService.updateDriverStatus(_selectedDriverUid!, 'busy');

      _loadPortController.clear();
      _unloadPortController.clear();
      _cargoTypeController.clear();
      _cargoDescriptionController.clear();
      _cargoWeightController.clear();

      setState(() {
        _selectedDriverUid = null;
        _selectedDriver = null;
        _selectedVehicleId = null;
        _selectedVehicle = null;
      });

      _showSnackBar("✓ Görev başarıyla oluşturuldu", isError: false);
    } catch (e) {
      _showSnackBar("Hata: $e", isError: true);
    } finally {
      setState(() => _isCreatingJob = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: isError ? error : success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _openDriverPanel() {
    setState(() => _showDriverPanel = true);
    _driverPanelController.forward();
  }

  void _closeDriverPanel() {
    _driverPanelController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showDriverPanel = false;
          _driverSearchQuery = '';
          _driverSearchController.clear();
        });
      }
    });
  }

  void _openVehiclePanel() {
    if (_selectedDriverUid == null) {
      _showSnackBar("Lütfen önce şoför seçin", isError: true);
      return;
    }
    setState(() => _showVehiclePanel = true);
    _vehiclePanelController.forward();
  }

  void _closeVehiclePanel() {
    _vehiclePanelController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showVehiclePanel = false;
          _vehicleSearchQuery = '';
          _vehicleSearchController.clear();
        });
      }
    });
  }

  void _selectDriver(Map<String, dynamic> driver) {
    setState(() {
      _selectedDriverUid = driver['uid'];
      _selectedDriver = driver;
      _selectedVehicleId = null;
      _selectedVehicle = null;
    });
    _closeDriverPanel();
  }

  void _selectVehicle(Map<String, dynamic> vehicle) {
    setState(() {
      _selectedVehicleId = vehicle['vehicleId'];
      _selectedVehicle = vehicle;
    });
    _closeVehiclePanel();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: textSecondary, size: 18),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📋 Header
                _buildHeader(),
                const SizedBox(height: 32),

                // 🚛 Şoför & Araç Seçimi
                Row(
                  children: [
                    Expanded(
                      child: DriverSelectionCard(
                        selectedDriver: _selectedDriver,
                        onTap: _openDriverPanel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: VehicleSelectionCard(
                        selectedVehicle: _selectedVehicle,
                        onTap: _openVehiclePanel,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 📦 Yükleme & Boşaltma Noktaları
                _buildRouteInfoSection(),
                const SizedBox(height: 24),

                // 📦 Kargo Detayları
                _buildCargoDetailsSection(),
                const SizedBox(height: 32),

                // ✅ Submit Button
                _buildSubmitButton(),
              ],
            ),
          ),

          // 🎭 Overlay Panels
          if (_showDriverPanel)
            DriverSelectionPanel(
              animation: _driverPanelAnimation,
              isDesktop: isDesktop,
              searchController: _driverSearchController,
              searchQuery: _driverSearchQuery,
              selectedDriverUid: _selectedDriverUid,
              onSearchChanged: (v) => setState(() => _driverSearchQuery = v.toLowerCase()),
              onClose: _closeDriverPanel,
              onSelectDriver: _selectDriver,
            ),
          if (_showVehiclePanel)
            VehicleSelectionPanel(
              animation: _vehiclePanelAnimation,
              isDesktop: isDesktop,
              searchController: _vehicleSearchController,
              searchQuery: _vehicleSearchQuery,
              selectedVehicleId: _selectedVehicleId,
              selectedDriverUid: _selectedDriverUid!,
              onSearchChanged: (v) => setState(() => _vehicleSearchQuery = v.toLowerCase()),
              onClose: _closeVehiclePanel,
              onSelectVehicle: _selectVehicle,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.add_task, color: primary, size: 24),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Yeni Görev Oluştur",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Şoför ve araç seçerek yeni bir görev atayın",
              style: TextStyle(fontSize: 14, color: textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRouteInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Rota Bilgileri",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loadPortController,
          decoration: _inputDecoration("Yükleme Noktası", Icons.upload_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _unloadPortController,
          decoration: _inputDecoration("Boşaltma Noktası", Icons.download_outlined),
        ),
      ],
    );
  }

  Widget _buildCargoDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Kargo Detayları",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cargoTypeController,
          decoration: _inputDecoration("Kargo Tipi", Icons.category_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cargoDescriptionController,
          maxLines: 3,
          decoration: _inputDecoration("Açıklama", Icons.description_outlined),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cargoWeightController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
          decoration: _inputDecoration("Ağırlık (kg)", Icons.scale_outlined),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isCreatingJob ? null : _createJob,
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isCreatingJob
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 22),
            SizedBox(width: 10),
            Text(
              "Görevi Oluştur",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}