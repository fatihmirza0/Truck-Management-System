import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LiveTrackingPanel extends StatefulWidget {
  const LiveTrackingPanel({super.key});

  @override
  State<LiveTrackingPanel> createState() => _LiveTrackingPanelState();
}

class _LiveTrackingPanelState extends State<LiveTrackingPanel> {
  final MapController _mapController = MapController();

  static const String _endpoint =
      'https://us-central1-truck-dispatch-system.cloudfunctions.net/getLiveDriverLocations';

  Timer? _timer;

  final Map<String, LiveDriver> _drivers = {};
  String? _selectedDriverId;
  bool _showHistory = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Filtreler
  String _statusFilter = 'all'; // all, online, busy, offline
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
    _timer = Timer.periodic(
      const Duration(seconds: 3),
          (_) => _fetchDrivers(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ======================================================
  // 🔥 FETCH DRIVERS
  // ======================================================
  Future<void> _fetchDrivers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Kullanıcı oturumu bulunamadı';
            _isLoading = false;
          });
        }
        return;
      }

      final token = await user.getIdToken();

      final res = await http.get(
        Uri.parse(_endpoint),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 401 || res.statusCode == 403) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Yetki hatası: ${res.statusCode}';
            _isLoading = false;
          });
        }
        return;
      }

      if (res.statusCode != 200) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Sunucu hatası: ${res.statusCode}';
            _isLoading = false;
          });
        }
        return;
      }

      if (res.body == 'null' || res.body.isEmpty || res.body == '{}') {
        if (mounted) {
          setState(() {
            _drivers.clear();
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final raw = jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, LiveDriver> temp = {};

      await Future.wait(
        raw.entries.map((entry) async {
          final driverId = entry.key;
          final data = entry.value as Map<String, dynamic>;

          final current = data['current'];
          final status = data['status'];

          if (current == null || status == null) return;

          // Firestore'dan bilgi çek
          String userName = '';
          String plate = '';
          String phone = '';

          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(driverId)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              userName = userData['name'] ?? '';
              phone = userData['phone'] ?? '';

              final activeVehicleId = userData['activeVehicleId'];
              if (activeVehicleId != null) {
                final vehicleDoc = await FirebaseFirestore.instance
                    .collection('vehicles')
                    .doc(activeVehicleId)
                    .get();

                if (vehicleDoc.exists) {
                  plate = vehicleDoc.data()?['plate'] ?? '';
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ Firestore error for $driverId: $e');
          }

          // History
          final List<LatLng> history = [];
          if (data['history'] != null) {
            final h = data['history'] as Map<String, dynamic>;
            final sorted = h.entries.toList()
              ..sort((a, b) =>
                  (a.value['timestamp'] ?? 0)
                      .compareTo(b.value['timestamp'] ?? 0));

            for (final e in sorted) {
              history.add(
                LatLng(
                  (e.value['latitude'] as num).toDouble(),
                  (e.value['longitude'] as num).toDouble(),
                ),
              );
            }
          }

          final lastSeen = status['lastSeen'] as int?;
          final currentJobId = status['currentJobId'] as String?;

          temp[driverId] = LiveDriver(
            driverId: driverId,
            plate: plate,
            name: userName,
            phone: phone,
            position: LatLng(
              (current['latitude'] as num).toDouble(),
              (current['longitude'] as num).toDouble(),
            ),
            heading: (current['heading'] ?? 0).toDouble(),
            speed: (current['speed'] ?? 0).toDouble(),
            accuracy: (current['accuracy'] ?? 0).toDouble(),
            isMoving: current['isMoving'] ?? false,
            status: status['status'] ?? 'offline',
            lastSeen: lastSeen != null
                ? DateTime.fromMillisecondsSinceEpoch(lastSeen)
                : null,
            currentJobId: currentJobId,
            history: history,
          );
        }),
      );

      if (mounted) {
        setState(() {
          _drivers.clear();
          _drivers.addAll(temp);
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = 'Bağlantı zaman aşımı';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ _fetchDrivers error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Veri yükleme hatası';
          _isLoading = false;
        });
      }
    }
  }

  // ======================================================
  // FILTER & SEARCH
  // ======================================================
  List<LiveDriver> get _filteredDrivers {
    var filtered = _drivers.values.toList();

    // Status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((d) => d.status == _statusFilter).toList();
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.name.toLowerCase().contains(query) ||
            d.plate.toLowerCase().contains(query) ||
            d.phone.toLowerCase().contains(query);
      }).toList();
    }

    // Sort by status priority
    filtered.sort((a, b) {
      final statusPriority = {'online': 0, 'busy': 1, 'offline': 2};
      final aPriority = statusPriority[a.status] ?? 3;
      final bPriority = statusPriority[b.status] ?? 3;
      return aPriority.compareTo(bPriority);
    });

    return filtered;
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final drivers = _filteredDrivers;
    final allDrivers = _drivers.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Canlı Takip'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          // Stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatBadge(
                  'Online',
                  allDrivers.where((d) => d.status == 'online').length,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Meşgul',
                  allDrivers.where((d) => d.status == 'busy').length,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatBadge(
                  'Offline',
                  allDrivers.where((d) => d.status == 'offline').length,
                  Colors.red,
                ),
              ],
            ),
          ),
          // History toggle
          Row(
            children: [
              const Text('Rota', style: TextStyle(fontSize: 13)),
              Switch(
                value: _showHistory,
                onChanged: (v) => setState(() => _showHistory = v),
              ),
            ],
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // ===============================
          // 🧭 LEFT PANEL
          // ===============================
          Container(
            width: 350,
            color: Colors.white,
            child: Column(
              children: [
                // Search & Filter
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Search
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Sürücü, plaka veya telefon ara...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                      const SizedBox(height: 8),
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('Tümü', 'all'),
                            _filterChip('Online', 'online'),
                            _filterChip('Meşgul', 'busy'),
                            _filterChip('Offline', 'offline'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // List
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Yükleniyor...'),
                      ],
                    ),
                  )
                      : _errorMessage != null
                      ? _buildErrorState()
                      : drivers.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _buildDriverTile(drivers[i]),
                  ),
                ),
              ],
            ),
          ),

          // ===============================
          // 🗺️ MAP
          // ===============================
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(38.6191, 27.4289),
                initialZoom: 8,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          ),
        ],
      ),
    );
  }

  // ======================================================
  // WIDGETS
  // ======================================================
  Widget _buildStatBadge(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = value),
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF1E3A5F).withOpacity(0.1),
        checkmarkColor: const Color(0xFF1E3A5F),
        side: BorderSide(
          color: selected
              ? const Color(0xFF1E3A5F)
              : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Widget _buildDriverTile(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;
    final timeAgo = d.lastSeen != null ? _getTimeAgo(d.lastSeen!) : '—';

    return ListTile(
      selected: selected,
      selectedTileColor: const Color(0xFFE0F2FE),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1E3A5F),
            child: Text(
              d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
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
      title: Text(
        d.plate.isNotEmpty ? d.plate : d.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.name.isNotEmpty && d.plate.isNotEmpty)
            Text(d.name, style: const TextStyle(fontSize: 12)),
          Row(
            children: [
              Icon(
                d.isMoving ? Icons.directions_car : Icons.stop_circle,
                size: 12,
                color: d.isMoving ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                d.isMoving ? '${d.speed.toStringAsFixed(0)} km/h' : 'Durgun',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 8),
              Text('• $timeAgo', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: selected ? const Color(0xFF1E3A5F) : Colors.grey,
      ),
      onTap: () {
        setState(() => _selectedDriverId = d.driverId);
        _mapController.move(d.position, 15);
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchDrivers();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
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
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'Sonuç bulunamadı'
                : 'Aktif sürücü yok',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;

    return Marker(
      width: 150,
      height: 100,
      point: d.position,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDriverId = d.driverId);
          _mapController.move(d.position, 15);
        },
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E3A5F)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    d.plate.isNotEmpty ? d.plate : '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  if (d.isMoving)
                    Text(
                      '${d.speed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Transform.rotate(
              angle: d.heading * pi / 180,
              child: Icon(
                Icons.navigation,
                size: 28,
                color: d.isMoving ? Colors.green : Colors.red,
                shadows: const [
                  Shadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // HELPERS
  // ======================================================
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

  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}s önce';
    return DateFormat('dd.MM HH:mm').format(time);
  }
}

// ======================================================
// MODEL
// ======================================================
class LiveDriver {
  final String driverId;
  final String plate;
  final String name;
  final String phone;
  final LatLng position;
  final double heading;
  final double speed;
  final double accuracy;
  final bool isMoving;
  final String status;
  final DateTime? lastSeen;
  final String? currentJobId;
  final List<LatLng> history;

  LiveDriver({
    required this.driverId,
    required this.plate,
    required this.name,
    required this.phone,
    required this.position,
    required this.heading,
    required this.speed,
    required this.accuracy,
    required this.isMoving,
    required this.status,
    this.lastSeen,
    this.currentJobId,
    required this.history,
  });
}