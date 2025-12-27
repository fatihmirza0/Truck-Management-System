import 'dart:async';
import 'dart:math';

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

class _LiveTrackingPanelState extends State<LiveTrackingPanel> {
  final MapController _mapController = MapController();
  final LiveTrackingService _service = LiveTrackingService();
  final ValueNotifier<List<LiveDriver>> _driversNotifier =
      ValueNotifier<List<LiveDriver>>([]);

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

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  @override
  void dispose() {
    _driversSubscription?.cancel();
    _service.dispose();
    _mapController.dispose();
    _driversNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      setState(() => _isLoading = true);
      await _service.preloadFirestore();

      _driversSubscription = _service.liveDrivers().listen(
        (drivers) {
          if (!mounted) return;
          _driversNotifier.value = drivers;

          if (_autoCenter && drivers.isNotEmpty) {
            _fitMapToDrivers(drivers);
          }

          if (_isLoading) {
            setState(() {
              _isLoading = false;
              _errorMessage = null;
            });
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Veri akışı hatası';
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Başlatma hatası: $e';
        _isLoading = false;
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
                                  strokeWidth: 3,
                                  color: const Color(0xFF3B82F6),
                                  borderStrokeWidth: 1,
                                  borderColor: Colors.white,
                                ))
                            .toList(),
                      ),
                    MarkerLayer(
                      markers: allDrivers.map(_marker).toList(),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Sürücü, plaka ara...',
                            hintStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.filter_list, size: 20),
                              onPressed: () => _showMobileFilters(),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMobileStatChip(
                            'Müsait',
                            allDrivers
                                .where((d) => d.status == 'online')
                                .length,
                            Colors.green,
                            Icons.check_circle,
                          ),
                          const SizedBox(width: 8),
                          _buildMobileStatChip(
                            'Meşgul',
                            allDrivers.where((d) => d.status == 'busy').length,
                            Colors.orange,
                            Icons.local_shipping,
                          ),
                          const SizedBox(width: 8),
                          _buildMobileStatChip(
                            'Pasif',
                            allDrivers
                                .where((d) => d.status == 'offline')
                                .length,
                            Colors.red,
                            Icons.remove_circle_outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'center',
                        backgroundColor: Colors.white,
                        onPressed: () => _fitMapToDrivers(allDrivers),
                        child: const Icon(Icons.center_focus_strong,
                            color: Color(0xFF1E3A5F)),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'layer',
                        backgroundColor: Colors.white,
                        onPressed: _showMapStylePicker,
                        child:
                            const Icon(Icons.layers, color: Color(0xFF1E3A5F)),
                      ),
                    ],
                  ),
                ),
                if (filtered.isNotEmpty)
                  DraggableScrollableSheet(
                    initialChildSize: 0.15,
                    minChildSize: 0.15,
                    maxChildSize: 0.7,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 20,
                              offset: Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: [
                                  const Text(
                                    'Aktif Sürücüler',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${filtered.length}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E3A5F),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
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
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: const Center(
                      child: CircularProgressIndicator(),
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
                    horizontal: isTablet ? 16 : 24,
                    vertical: isTablet ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8D)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
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
                          Icons.map_outlined,
                          color: Colors.white,
                          size: 24,
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
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Gerçek zamanlı güncelleniyor',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
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
                          Icons.check_circle,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildDesktopStatCard(
                          'Meşgul',
                          allDrivers.where((d) => d.status == 'busy').length,
                          Icons.local_shipping,
                          Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        _buildDesktopStatCard(
                          'Pasif',
                          allDrivers.where((d) => d.status == 'offline').length,
                          Icons.remove_circle_outline,
                          Colors.red,
                        ),
                        const SizedBox(width: 16),
                      ],
                      _buildHeaderButton(
                        icon: _showHistory ? Icons.route : Icons.route_outlined,
                        label: 'Rota',
                        isActive: _showHistory,
                        onTap: () =>
                            setState(() => _showHistory = !_showHistory),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderButton(
                        icon:
                            _autoCenter ? Icons.gps_fixed : Icons.gps_not_fixed,
                        label: 'Merkez',
                        isActive: _autoCenter,
                        onTap: () => setState(() => _autoCenter = !_autoCenter),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderButton(
                        icon: Icons.layers_outlined,
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
                      duration: const Duration(milliseconds: 300),
                      width: isTablet ? 320 : 400,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              border: Border(
                                bottom: BorderSide(
                                  color:
                                      const Color(0xFFE2E8F0).withOpacity(0.5),
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
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 18),
                                            onPressed: () => setState(
                                                () => _searchQuery = ''),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
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
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _filterChip('Tümü', 'all', Icons.apps),
                                      _filterChip('Meşgul', 'busy',
                                          Icons.local_shipping),
                                      _filterChip('Müsait', 'online',
                                          Icons.check_circle),
                                      _filterChip('Pasif', 'offline',
                                          Icons.remove_circle_outline),
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
                                if (_errorMessage != null)
                                  return _buildErrorState();
                                if (filtered.isEmpty) return _buildEmptyState();

                                return ListView.builder(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
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
                                if (_showHistory && _selectedDriverId != null)
                                  PolylineLayer(
                                    polylines: allDrivers
                                        .where((d) =>
                                            d.driverId == _selectedDriverId &&
                                            d.history.length > 1)
                                        .map((d) => Polyline(
                                              points: d.history,
                                              strokeWidth: 4,
                                              color: const Color(0xFF3B82F6),
                                              borderStrokeWidth: 2,
                                              borderColor: Colors.white,
                                            ))
                                        .toList(),
                                  ),
                                MarkerLayer(
                                  markers: allDrivers.map(_marker).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _showSidePanel = !_showSidePanel),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _showSidePanel
                                      ? Icons.chevron_left
                                      : Icons.menu,
                                  color: const Color(0xFF1E3A5F),
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

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive
          ? Colors.white.withOpacity(0.2)
          : Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
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
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
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
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _getStatusColor(d.status),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
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
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(d.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusLabel(d.status),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _getStatusColor(d.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (d.name.isNotEmpty && d.plate.isNotEmpty)
                        Text(
                          d.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            d.isMoving
                                ? Icons.directions_car
                                : Icons.stop_circle,
                            size: 13,
                            color: d.isMoving
                                ? Colors.green
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
                                  ? Colors.green
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.access_time,
                            size: 11,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF0F9FF) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0),
          width: selected ? 2 : 1,
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
                      width: 44,
                      height: 44,
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
                      Text(
                        d.plate.isNotEmpty ? d.plate : d.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            d.isMoving
                                ? Icons.directions_car
                                : Icons.stop_circle,
                            size: 12,
                            color: d.isMoving ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.isMoving
                                ? '${d.speed.toStringAsFixed(0)} km/h'
                                : 'Durgun',
                            style: TextStyle(
                              fontSize: 11,
                              color: d.isMoving ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 10,
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
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(d.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(d.status),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(d.status),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
          ),
          SizedBox(height: 16),
          Text(
            'Sürücüler yükleniyor...',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _initializeTracking();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 56,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'Aktif sürücü yok',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Farklı bir arama deneyin'
                : 'Sürücüler takip başlattığında görünecek',
            style: const TextStyle(
              fontSize: 13,
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _statusFilter = value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
      width: 160,
      height: 110,
      point: d.position,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDriverId = d.driverId);
          _mapController.move(d.position, 15);
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      selected ? const Color(0xFF1E3A5F) : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    d.plate.isNotEmpty ? d.plate : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  if (d.isMoving) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${d.speed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Transform.rotate(
              angle: d.heading * pi / 180,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _getStatusColor(d.status),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _getStatusColor(d.status).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation,
                  size: 20,
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
        title: const Text('Harita Stili'),
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
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupValue: _mapStyle,
        onChanged: (v) {
          setState(() => _mapStyle = v!);
          Navigator.pop(context);
        },
      ),
      title: Text(label),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrele',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mobileFilterChip('Tümü', 'all', setModalState),
                  _mobileFilterChip('Müsait', 'online', setModalState),
                  _mobileFilterChip('Meşgul', 'busy', setModalState),
                  _mobileFilterChip('Pasif', 'offline', setModalState),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Harita Stili',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
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
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
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
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      default:
        return Colors.red;
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
