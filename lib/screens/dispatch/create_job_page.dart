import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/utils/route_utils.dart';

class CreateJobPage extends StatefulWidget {
  const CreateJobPage({super.key});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage>
    with TickerProviderStateMixin {
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
  static const Color primary = Color(0xFF1E293B);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentLight = Color(0xFFEFF6FF);
  static const Color success = Color(0xFF10B981);
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
      duration: const Duration(milliseconds: 350),
    );
    _driverPanelAnimation = CurvedAnimation(
      parent: _driverPanelController,
      curve: Curves.easeOutCubic,
    );
    _vehiclePanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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
    if (loadPort.isEmpty ||
        unloadPort.isEmpty ||
        cargoType.isEmpty ||
        cargoDescription.isEmpty ||
        cargoWeightStr.isEmpty ||
        _selectedDriverUid == null ||
        _selectedVehicleId == null) {
      _showSnackBar("Lütfen tüm alanları doldurun ve şoför/araç seçin",
          isError: true);
      return;
    }

    final cargoWeight = double.tryParse(cargoWeightStr);
    if (cargoWeight == null || cargoWeight <= 0) {
      _showSnackBar("Lütfen geçerli bir ağırlık girin", isError: true);
      return;
    }

    setState(() => _isCreatingJob = true);

    try {
      // Şoför status kontrolü
      final driverStatus =
          await FirestoreService.getDriverStatus(_selectedDriverUid!);
      if (driverStatus == 'busy') {
        _showSnackBar(
            "Bu şoför zaten aktif bir görevde. Lütfen başka şoför seçin.",
            isError: true);
        setState(() => _isCreatingJob = false);
        return;
      }

      // Koordinatları bul
      final loadCoords = await RouteUtils.geocode(loadPort);
      final unloadCoords = await RouteUtils.geocode(unloadPort);

      if (loadCoords == null || unloadCoords == null) {
        _showSnackBar(
            "Adresler koordinata çevrilemedi. Lütfen geçerli adresler girin.",
            isError: true);
        setState(() => _isCreatingJob = false);
        return;
      }

      // Google Directions API ile mesafe hesapla
      double distanceKm = await RouteUtils.getRouteKm(
        loadCoords['lat']!,
        loadCoords['lng']!,
        unloadCoords['lat']!,
        unloadCoords['lng']!,
      );

      // API başarısız olursa Haversine fallback
      if (distanceKm == 0) {
        distanceKm = RouteUtils.haversineKm(
          loadCoords['lat']!,
          loadCoords['lng']!,
          unloadCoords['lat']!,
          unloadCoords['lng']!,
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
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  Icon(Icons.person_add_outlined,
                      color: Color(0xFF1E3A5F), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text("Şoför Seç",
                          style: TextStyle(
                              fontSize: 15,
                              color: textSecondary,
                              fontWeight: FontWeight.w500))),
                  Icon(Icons.arrow_forward_ios, color: textSecondary, size: 16),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(10)),
                    child:
                        const Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedDriver!['name'],
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 2),
                        Text(_selectedDriver!['email'] ?? '-',
                            style: const TextStyle(
                                fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: accent, size: 22),
                ],
              ),
      ),
    );
  }

  Widget _buildVehicleSelectionCard() {
    return GestureDetector(
      onTap: _openVehiclePanel,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedVehicle == null ? cardBg : accentLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedVehicle == null ? border : accent,
            width: _selectedVehicle == null ? 1 : 2,
          ),
        ),
        child: _selectedVehicle == null
            ? Row(
                children: const [
                  Icon(Icons.local_shipping_outlined,
                      color: Color(0xFF1E3A5F), size: 22),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text("Araç Seç",
                          style: TextStyle(
                              fontSize: 15,
                              color: textSecondary,
                              fontWeight: FontWeight.w500))),
                  Icon(Icons.arrow_forward_ios, color: textSecondary, size: 16),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_shipping,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedVehicle!['plate'],
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        const SizedBox(height: 2),
                        Text(_selectedVehicle!['type'] ?? '-',
                            style: const TextStyle(
                                fontSize: 13, color: textSecondary)),
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
        GestureDetector(
          onTap: _closeDriverPanel,
          child: AnimatedBuilder(
            animation: _driverPanelAnimation,
            builder: (context, child) => Container(
                color: Colors.black
                    .withOpacity(0.4 * _driverPanelAnimation.value)),
          ),
        ),
        Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _driverPanelAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0,
                    isDesktop
                        ? (1 - _driverPanelAnimation.value) * 50
                        : (1 - _driverPanelAnimation.value) * 500),
                child:
                    Opacity(opacity: _driverPanelAnimation.value, child: child),
              );
            },
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              height:
                  isDesktop ? 500 : MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: isDesktop
                    ? BorderRadius.circular(16)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isDesktop ? 16 : 24),
                          topRight: Radius.circular(isDesktop ? 16 : 24)),
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
                                      borderRadius: BorderRadius.circular(2)))),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: accentLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.person,
                                  color: Color(0xFF1E3A5F), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                                child: Text("Şoför Seç",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary))),
                            IconButton(
                                onPressed: _closeDriverPanel,
                                icon: const Icon(Icons.close, size: 22),
                                color: textSecondary),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _driverSearchController,
                          onChanged: (v) => setState(
                              () => _driverSearchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: "İsim, e-posta veya plaka ara...",
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search,
                                color: textSecondary, size: 20),
                            filled: true,
                            fillColor: bg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService.fetchDrivers(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final drivers = snap.data!.where((d) {
                          if (_driverSearchQuery.isEmpty) return true;

                          final q = _driverSearchQuery;

                          return d['name']
                                  .toString()
                                  .toLowerCase()
                                  .contains(q) ||
                              d['email'].toString().toLowerCase().contains(q) ||
                              (d['activePlate'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(q); // 🔥 plaka arama
                        }).toList();

                        if (drivers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.search_off,
                                    size: 48, color: textSecondary),
                                SizedBox(height: 12),
                                Text("Şoför bulunamadı",
                                    style: TextStyle(
                                        fontSize: 15, color: textSecondary)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: drivers.length,
                          itemBuilder: (context, i) {
                            final driver = drivers[i];
                            final isSelected =
                                driver['uid'] == _selectedDriverUid;
                            final jobStatus =
                                driver['jobStatus'] ?? 'available';
                            final isBusy = jobStatus == 'busy';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentLight
                                    : isBusy
                                        ? const Color(0xFFFEF2F2)
                                        : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected
                                        ? accent
                                        : isBusy
                                            ? const Color(0xFFEF4444)
                                            : border,
                                    width: isSelected ? 2 : 1),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isBusy
                                      ? null
                                      : () => _selectDriver(driver),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                              color: isBusy
                                                  ? const Color(0xFFEF4444)
                                                  : accent,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: Icon(
                                              isBusy
                                                  ? Icons.work_outline
                                                  : Icons.person_outlined,
                                              color: Colors.white,
                                              size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      driver['name'],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: isBusy
                                                            ? textSecondary
                                                            : textPrimary,
                                                      ),
                                                    ),
                                                  ),

                                                  // 🔥 STATUS BADGE (HER ZAMAN GÖRÜNÜR)
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: isBusy
                                                          ? const Color(
                                                              0xFFEF4444) // kırmızı
                                                          : const Color(
                                                              0xFF10B981), // yeşil
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      isBusy
                                                          ? "MEŞGUL"
                                                          : "MÜSAİT",
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: .3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 4),

                                              Text(
                                                driver['email'],
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: textSecondary,
                                                ),
                                              ),

                                              // ⭐ Opsiyonel: aktif plaka gösterimi
                                              if (driver['activePlate'] !=
                                                  null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  "Araç: ${driver['activePlate']}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: textSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle,
                                              color: accent, size: 22),
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

  Widget _buildVehiclePanel() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _closeVehiclePanel,
          child: AnimatedBuilder(
            animation: _vehiclePanelAnimation,
            builder: (context, child) => Container(
                color: Colors.black
                    .withOpacity(0.4 * _vehiclePanelAnimation.value)),
          ),
        ),
        Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _vehiclePanelAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                    0,
                    isDesktop
                        ? (1 - _vehiclePanelAnimation.value) * 50
                        : (1 - _vehiclePanelAnimation.value) * 500),
                child: Opacity(
                    opacity: _vehiclePanelAnimation.value, child: child),
              );
            },
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              height:
                  isDesktop ? 500 : MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: isDesktop
                    ? BorderRadius.circular(16)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isDesktop ? 16 : 24),
                          topRight: Radius.circular(isDesktop ? 16 : 24)),
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
                                      borderRadius: BorderRadius.circular(2)))),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: accentLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.local_shipping,
                                  color: Color(0xFF1E3A5F), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                                child: Text("Araç Seç",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary))),
                            IconButton(
                                onPressed: _closeVehiclePanel,
                                icon: const Icon(Icons.close, size: 22),
                                color: textSecondary),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _vehicleSearchController,
                          onChanged: (v) => setState(
                              () => _vehicleSearchQuery = v.toLowerCase()),
                          decoration: InputDecoration(
                            hintText: "Ara...",
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search,
                                color: textSecondary, size: 20),
                            filled: true,
                            fillColor: bg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: FirestoreService.fetchVehiclesByDriver(
                          _selectedDriverUid!),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final vehicles = snap.data!.where((v) {
                          if (_vehicleSearchQuery.isEmpty) return true;
                          return v['plate']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_vehicleSearchQuery) ||
                              v['type']
                                  .toString()
                                  .toLowerCase()
                                  .contains(_vehicleSearchQuery);
                        }).toList();

                        if (vehicles.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.search_off,
                                    size: 48, color: textSecondary),
                                SizedBox(height: 12),
                                Text("Bu şoföre atanmış araç bulunamadı",
                                    style: TextStyle(
                                        fontSize: 15, color: textSecondary)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: vehicles.length,
                          itemBuilder: (context, i) {
                            final vehicle = vehicles[i];
                            final isSelected =
                                vehicle['vehicleId'] == _selectedVehicleId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? accentLight : cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected ? accent : border,
                                    width: isSelected ? 2 : 1),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _selectVehicle(vehicle),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                              color: accent,
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: const Icon(
                                              Icons.local_shipping_outlined,
                                              color: Colors.white,
                                              size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(vehicle['plate'],
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: textPrimary)),
                                              const SizedBox(height: 3),
                                              Text(
                                                  "${vehicle['type']} - ${vehicle['ownership']}",
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: textSecondary)),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(Icons.check_circle,
                                              color: accent, size: 22),
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
    return Stack(
      children: [
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1E3A5F),
                              primary.withOpacity(0.85)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.assignment_add,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Yeni İş Oluştur",
                                    style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                                SizedBox(height: 3),
                                Text("Sevkiyat detaylarını girin",
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Sevkiyat Bilgileri",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary)),
                          const SizedBox(height: 16),
                          if (isDesktop)
                            Row(
                              children: [
                                Expanded(
                                    child: TextField(
                                        controller: _loadPortController,
                                        decoration: _input("Yükleme Noktası",
                                            Icons.location_on_outlined))),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: TextField(
                                        controller: _unloadPortController,
                                        decoration: _input("Varış Noktası",
                                            Icons.flag_outlined))),
                              ],
                            )
                          else ...[
                            TextField(
                                controller: _loadPortController,
                                decoration: _input("Yükleme Noktası",
                                    Icons.location_on_outlined)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _unloadPortController,
                                decoration: _input(
                                    "Varış Noktası", Icons.flag_outlined)),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                              controller: _cargoTypeController,
                              decoration: _input(
                                  "Yük Tipi", Icons.inventory_2_outlined)),
                          const SizedBox(height: 12),
                          TextField(
                              controller: _cargoDescriptionController,
                              maxLines: 2,
                              decoration: _input("Yük Açıklaması",
                                  Icons.description_outlined)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cargoWeightController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+.?\d{0,2}'))
                            ],
                            decoration:
                                _input("Ağırlık (kg)", Icons.scale_outlined),
                          ),
                          const SizedBox(height: 20),
                          const Text("Atama Bilgileri",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary)),
                          const SizedBox(height: 12),
                          _buildDriverSelectionCard(),
                          const SizedBox(height: 12),
                          _buildVehicleSelectionCard(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isCreatingJob ? null : _createJob,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A5F),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isCreatingJob
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text("Görevi Oluştur",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
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
        if (_showDriverPanel) _buildDriverPanel(),
        if (_showVehiclePanel) _buildVehiclePanel(),
      ],
    );
  }
}
