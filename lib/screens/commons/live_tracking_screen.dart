import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import 'package:lojistik/services/live_tracking_service.dart';

class LiveTrackingPanel extends StatefulWidget {
  const LiveTrackingPanel({super.key});

  @override
  State<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends State<LiveTrackingPanel>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LiveTrackingService _service = LiveTrackingService();
  final ValueNotifier<List<LiveDriver>> _driversNotifier =
      ValueNotifier<List<LiveDriver>>([]);
  bool _isStreamActive = false; // 🔥 YENİ: Stream kontrolü

  StreamSubscription<List<LiveDriver>>? _driversSubscription;

  String? _selectedDriverId;
  bool _showHistory = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showSidePanel = true;
  bool _autoCenter = false;

  String _statusFilter = 'all';
  String _searchQuery = '';
  String _mapStyle = 'osm';

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _initializeTracking();
  }

  @override
  void dispose() {
    _isStreamActive = false; // 🔥 Stream'i durdur

    _driversSubscription?.cancel();
    _service.dispose();
    _mapController.dispose();
    _driversNotifier.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    if (_isStreamActive) {
      debugPrint('⚠️ Tracking already active');
      return;
    }

    try {
      setState(() => _isLoading = true);

      await _service.preloadFirestore();

      _isStreamActive = true; // 🔥 Stream başladı

      _driversSubscription = _service.liveDrivers().listen(
        (drivers) {
          if (!mounted || !_isStreamActive) return; // 🔥 Kontrol ekle

          _driversNotifier.value = drivers;

          if (_autoCenter && drivers.isNotEmpty) {
            _fitMapToDrivers(drivers);
          }

          if (_isLoading && mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          if (!mounted || !_isStreamActive) return;

          debugPrint('❌ Stream error: $error');
          if (mounted) {
            setState(() {
              _errorMessage = 'Veri akışı hatası: $error';
              _isLoading = false;
            });
          }
        },
        onDone: () {
          debugPrint('✅ Stream completed');
          _isStreamActive = false;
        },
        cancelOnError: false, // 🔥 Hata olsa bile stream devam etsin
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('❌ Initialize error: $e');
      setState(() {
        _errorMessage = 'Başlatma hatası: $e';
        _isLoading = false;
        _isStreamActive = false;
      });
    }
  }

  void _fitMapToDrivers(List<LiveDriver> drivers) {
    if (drivers.isEmpty) return;

    final points = drivers.map((d) => d.position).toList();
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    _mapController.move(center, 10);
  }

  List<LiveDriver> _applyFilters(List<LiveDriver> list) {
    var filtered = list;

    if (_statusFilter != 'all') {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.plate.toLowerCase().contains(q) ||
              d.phone.toLowerCase().contains(q))
          .toList();
    }

    filtered.sort((a, b) {
      final order = {'busy': 0, 'online': 1, 'offline': 2};
      return (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
    });

    return filtered;
  }

  String _getMapTileUrl() {
    switch (_mapStyle) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'dark':
        return 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet = MediaQuery.of(context).size.width < 1024;

    if (isMobile) {
      return _buildMobileLayout();
    }

    return _buildDesktopLayout(isTablet);
  }

// 🔥 SADECE _buildMobileLayout() METODUNU DEĞİŞTİRDİM

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ValueListenableBuilder<List<LiveDriver>>(
          valueListenable: _driversNotifier,
          builder: (_, allDrivers, __) {
            final filtered = _applyFilters(allDrivers);

            return Stack(
              children: [
                // ============= HARITA =============
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(38.6191, 27.4289),
                    initialZoom: 8,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _getMapTileUrl(),
                      userAgentPackageName: 'com.truck.management.system',
                    ),
                    if (_showHistory && _selectedDriverId != null)
                      PolylineLayer(
                        polylines: allDrivers
                            .where((d) =>
                                d.driverId == _selectedDriverId &&
                                d.history.length > 1)
                            .map((d) => Polyline(
                                  points: d.history,
                                  strokeWidth: 3.5,
                                  color: const Color(0xFF3B82F6),
                                  borderStrokeWidth: 1.5,
                                  borderColor: Colors.white,
                                  gradientColors: [
                                    const Color(0xFF3B82F6)
                                        .withValues(alpha: 0.3),
                                    const Color(0xFF3B82F6),
                                  ],
                                ))
                            .toList(),
                      ),
                    MarkerLayer(
                      markers: allDrivers.map(_marker).toList(),
                    ),
                  ],
                ),

                // ============= ARAMA & STATS =============
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      // Arama
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Sürücü, plaka ara...',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 22,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stats
                      Row(
                        children: [
                          _buildMobileStatChip(
                            'Müsait',
                            allDrivers
                                .where((d) => d.status == 'online')
                                .length,
                            const Color(0xFF10B981),
                            Icons.check_circle_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildMobileStatChip(
                            'Meşgul',
                            allDrivers.where((d) => d.status == 'busy').length,
                            const Color(0xFFF59E0B),
                            Icons.local_shipping_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildMobileStatChip(
                            'Pasif',
                            allDrivers
                                .where((d) => d.status == 'offline')
                                .length,
                            const Color(0xFFEF4444),
                            Icons.remove_circle_outline_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ============= FLOATING BUTTONS (SAĞ ALT) =============
                Positioned(
                  bottom: 180, // 🔥 Bottom sheet'in üstünde
                  right: 16,
                  child: Column(
                    children: [
                      _buildFloatingButton(
                        icon: Icons.center_focus_strong_rounded,
                        onPressed: () => _fitMapToDrivers(allDrivers),
                        tooltip: 'Merkeze Al',
                      ),
                      const SizedBox(height: 12),
                      _buildFloatingButton(
                        icon: Icons.layers_rounded,
                        onPressed: _showMapStylePicker,
                        tooltip: 'Harita Stili',
                      ),
                    ],
                  ),
                ),

                // ============= BOTTOM SHEET (SÜRÜCÜLER) =============
                if (filtered.isNotEmpty)
                  DraggableScrollableSheet(
                    initialChildSize: 0.25, // 🔥 Biraz daha büyük başlangıç
                    minChildSize: 0.15, // 🔥 Daha küçük minimum
                    maxChildSize: 0.8, // 🔥 Daha büyük maksimum
                    snap: true, // 🔥 YENİ: Snap noktaları
                    snapSizes: const [
                      0.15,
                      0.25,
                      0.5,
                      0.8
                    ], // 🔥 YENİ: Snap pozisyonları
                    builder: (context, scrollController) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 32,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 🔥 HANDLE (Kaydırma Butonu)
                            GestureDetector(
                              onTap: () {
                                // Tap'e basınca açılsın
                                DraggableScrollableActuator.reset(context);
                              },
                              child: Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Container(
                                    width: 48,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // 🔥 HEADER (Tıklanabilir Filtre)
                            InkWell(
                              onTap: () => _showMobileFilters(),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Aktif Sürücüler',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF1E3A5F),
                                            Color(0xFF2D5F8D)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${filtered.length}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.tune_rounded,
                                      size: 20,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 🔥 SÜRÜCÜ LİSTESİ
                            Expanded(
                              child: ListView.builder(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) =>
                                    _buildMobileDriverCard(filtered[i]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                // ============= LOADING STATE =============
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Sistem başlatılıyor...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isTablet) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<List<LiveDriver>>(
              valueListenable: _driversNotifier,
              builder: (_, allDrivers, __) {
                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 28,
                    vertical: isTablet ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E3A5F)
                                  .withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Canlı Takip Sistemi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (_, __) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.4 *
                                                    _pulseController.value),
                                            blurRadius: 8,
                                            spreadRadius:
                                                2 * _pulseController.value,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 7),
                                const Text(
                                  'Gerçek zamanlı güncelleniyor',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isTablet) ...[
                        _buildDesktopStatCard(
                          'Müsait',
                          allDrivers.where((d) => d.status == 'online').length,
                          Icons.check_circle_rounded,
                          const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 16),
                        _buildDesktopStatCard(
                          'Meşgul',
                          allDrivers.where((d) => d.status == 'busy').length,
                          Icons.local_shipping_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 16),
                        _buildDesktopStatCard(
                          'Pasif',
                          allDrivers.where((d) => d.status == 'offline').length,
                          Icons.remove_circle_outline_rounded,
                          const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 24),
                      ],
                      _buildHeaderButton(
                        icon: _showHistory
                            ? Icons.route_rounded
                            : Icons.route_outlined,
                        label: 'Rota',
                        isActive: _showHistory,
                        onTap: () =>
                            setState(() => _showHistory = !_showHistory),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderButton(
                        icon: _autoCenter
                            ? Icons.gps_fixed_rounded
                            : Icons.gps_not_fixed_rounded,
                        label: 'Merkez',
                        isActive: _autoCenter,
                        onTap: () => setState(() => _autoCenter = !_autoCenter),
                      ),
                      const SizedBox(width: 12),
                      _buildHeaderButton(
                        icon: Icons.layers_rounded,
                        label: 'Katman',
                        onTap: _showMapStylePicker,
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Row(
                children: [
                  if (_showSidePanel)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      width: isTablet ? 340 : 420,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFE2E8F0)
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Sürücü, plaka ara...',
                                    hintStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              size: 18,
                                            ),
                                            onPressed: () => setState(
                                                () => _searchQuery = ''),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1E3A5F),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                ),
                                const SizedBox(height: 16),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filterChip(
                                          'Tümü', 'all', Icons.apps_rounded),
                                      _filterChip('Meşgul', 'busy',
                                          Icons.local_shipping_rounded),
                                      _filterChip('Müsait', 'online',
                                          Icons.check_circle_rounded),
                                      _filterChip('Pasif', 'offline',
                                          Icons.remove_circle_outline_rounded),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ValueListenableBuilder<List<LiveDriver>>(
                              valueListenable: _driversNotifier,
                              builder: (_, drivers, __) {
                                final filtered = _applyFilters(drivers);

                                if (_isLoading) return _buildLoadingState();
                                if (_errorMessage != null) {
                                  return _buildErrorState();
                                }
                                if (filtered.isEmpty) return _buildEmptyState();

                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) =>
                                      _buildDriverCard(filtered[i]),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        ValueListenableBuilder<List<LiveDriver>>(
                          valueListenable: _driversNotifier,
                          builder: (_, allDrivers, __) {
                            return FlutterMap(
                              mapController: _mapController,
                              options: const MapOptions(
                                initialCenter: LatLng(38.6191, 27.4289),
                                initialZoom: 8,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: _getMapTileUrl(),
                                  userAgentPackageName:
                                      'com.truck.management.system',
                                ),
                                // 🔧 FlutterMap children içinde - Polyline kısmını değiştir:

                                if (_showHistory && _selectedDriverId != null)
                                  PolylineLayer(
                                    polylines: allDrivers
                                        .where((d) =>
                                            d.driverId == _selectedDriverId &&
                                            d.history.length > 1)
                                        .map((d) {
                                      debugPrint(
                                          '🗺️ Drawing history for ${d.plate}: ${d.history.length} points');
                                      return Polyline(
                                        points: d.history,
                                        strokeWidth: 3.5,
                                        // Mobile için 3.5, Desktop için 4.5
                                        color: const Color(0xFF3B82F6),
                                        borderStrokeWidth: 1.5,
                                        // Mobile için 1.5, Desktop için 2
                                        borderColor: Colors.white,
                                        gradientColors: [
                                          const Color(0xFF3B82F6)
                                              .withValues(alpha: 0.3),
                                          const Color(0xFF3B82F6),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                // ✅ History buton durumunu göster (Header'a ekle - isteğe bağlı)
                                _buildHeaderButton(
                                  icon: _showHistory
                                      ? Icons.route_rounded
                                      : Icons.route_outlined,
                                  label:
                                      'Rota ${_selectedDriverId != null ? "(${allDrivers.firstWhere((d) => d.driverId == _selectedDriverId, orElse: () => allDrivers.first).history.length})" : ""}',
                                  isActive: _showHistory,
                                  onTap: () {
                                    if (_selectedDriverId == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Lütfen önce bir sürücü seçin'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(
                                        () => _showHistory = !_showHistory);
                                  },
                                ),
                                MarkerLayer(
                                  markers: allDrivers.map(_marker).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        Positioned(
                          left: 20,
                          top: 20,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(14),
                            shadowColor: Colors.black.withValues(alpha: 0.2),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _showSidePanel = !_showSidePanel),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _showSidePanel
                                      ? Icons.chevron_left_rounded
                                      : Icons.menu_rounded,
                                  color: const Color(0xFF1E3A5F),
                                  size: 24,
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF1E3A5F),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive
          ? const Color(0xFF1E3A5F).withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF1E3A5F).withValues(alpha: 0.3)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStatCard(
      String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color.withValues(alpha: 0.9),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatChip(
      String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;
    final timeAgo = d.lastSeen != null ? _getTimeAgo(d.lastSeen!) : '—';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedDriverId = d.driverId);
            _mapController.move(d.position, 15);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: selected
                              ? [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF2563EB)
                                ]
                              : [
                                  const Color(0xFF1E3A5F),
                                  const Color(0xFF2D5F8D)
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _getStatusColor(d.status),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d.plate.isNotEmpty ? d.plate : d.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(d.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusLabel(d.status),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(d.status),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (d.name.isNotEmpty && d.plate.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            d.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Icon(
                            d.isMoving
                                ? Icons.directions_car_rounded
                                : Icons.stop_circle_rounded,
                            size: 12,
                            color: d.isMoving
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.isMoving
                                ? '${d.speed.toStringAsFixed(0)} km/h'
                                : 'Durgun',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: d.isMoving
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 3),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDriverCard(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;
    final timeAgo = d.lastSeen != null ? _getTimeAgo(d.lastSeen!) : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0F9FF) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _selectedDriverId = d.driverId);
            _mapController.move(d.position, 16);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(d.status),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.plate.isNotEmpty ? d.plate : d.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            d.isMoving
                                ? Icons.directions_car_rounded
                                : Icons.stop_circle_rounded,
                            size: 11,
                            color: d.isMoving
                                ? const Color(0xFF10B981)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.isMoving
                                ? '${d.speed.toStringAsFixed(0)} km/h'
                                : 'Durgun',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: d.isMoving
                                  ? const Color(0xFF10B981)
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStatusColor(d.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(d.status),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(d.status),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sürücüler yükleniyor...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                if (!mounted) return; // 🔥 mounted kontrolü

                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });

                // 🔥 Stream'i durdur ve yeniden başlat
                await _driversSubscription?.cancel();
                _driversSubscription = null;
                _isStreamActive = false;

                await _initializeTracking();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 64,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'Aktif sürücü yok',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Farklı bir arama deneyin'
                : 'Sürücüler takip başlattığında görünecek',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? const Color(0xFF1E3A5F) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _statusFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Marker _marker(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;

    return Marker(
      width: 140,
      height: 90,
      point: d.position,
      child: GestureDetector(
        onTap: () {
          if (!mounted) return; // 🔥 mounted kontrolü

          setState(() => _selectedDriverId = d.driverId);

          try {
            _mapController.move(d.position, 15);
          } catch (e) {
            debugPrint('⚠️ Map move error: $e');
          }
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE2E8F0),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d.plate.isNotEmpty ? d.plate : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF1E3A5F),
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (d.isMoving) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${d.speed.toStringAsFixed(0)} km/h',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Transform.rotate(
              angle: (d.heading * pi / 180).clamp(-pi, pi), // 🔥 Angle clamp
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _getStatusColor(d.status),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(d.status).withValues(alpha: 0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapStylePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Harita Stili',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _mapStyleOption('Standart', 'osm'),
            _mapStyleOption('Uydu', 'satellite'),
            _mapStyleOption('Karanlık', 'dark'),
          ],
        ),
      ),
    );
  }

  Widget _mapStyleOption(String label, String value) {
    final selected = _mapStyle == value;
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupValue: _mapStyle,
        onChanged: (v) {
          setState(() => _mapStyle = v!);
          Navigator.pop(context);
        },
        activeColor: const Color(0xFF1E3A5F),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      onTap: () {
        setState(() => _mapStyle = value);
        Navigator.pop(context);
      },
    );
  }

  void _showMobileFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrele',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _mobileFilterChip('Tümü', 'all', setModalState),
                  _mobileFilterChip('Müsait', 'online', setModalState),
                  _mobileFilterChip('Meşgul', 'busy', setModalState),
                  _mobileFilterChip('Pasif', 'offline', setModalState),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Harita Stili',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: [
                  _mobileMapStyleChip('Standart', 'osm', setModalState),
                  _mobileMapStyleChip('Uydu', 'satellite', setModalState),
                  _mobileMapStyleChip('Karanlık', 'dark', setModalState),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileFilterChip(
      String label, String value, StateSetter setModalState) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() => _statusFilter = value);
        setModalState(() {});
      },
      selectedColor: const Color(0xFF1E3A5F),
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF64748B),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _mobileMapStyleChip(
      String label, String value, StateSetter setModalState) {
    final selected = _mapStyle == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() => _mapStyle = value);
        setModalState(() {});
      },
      selectedColor: const Color(0xFF1E3A5F),
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF64748B),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return const Color(0xFF10B981);
      case 'busy':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'online':
        return 'MÜSAİT';
      case 'busy':
        return 'MEŞGUL';
      default:
        return 'PASİF';
    }
  }

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}s';
    return DateFormat('dd.MM HH:mm').format(time);
  }
}
