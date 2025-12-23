import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
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
  // 🔥 HTTP FETCH (Cloud Function)
  // ======================================================
  Future<void> _fetchDrivers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();

      final res = await http.get(
        Uri.parse(_endpoint),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200 || res.body == 'null') return;

      final raw = jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, LiveDriver> temp = {};

      raw.forEach((driverId, data) {
        final current = data['current'];
        final status = data['status'];

        if (current == null || status == null) return;

        // HISTORY
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

        temp[driverId] = LiveDriver(
          driverId: driverId,
          plate: (data['activePlate'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          position: LatLng(
            (current['latitude'] as num).toDouble(),
            (current['longitude'] as num).toDouble(),
          ),
          heading: (current['heading'] ?? 0).toDouble(),
          isMoving: current['isMoving'] ?? false,
          status: status['status'] ?? 'offline',
          history: history,
        );
      });

      _drivers
        ..clear()
        ..addAll(temp);

      if (mounted) setState(() {});
    } catch (_) {
      // desktop silent fail
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final drivers = _drivers.values.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Canlı Takip'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          Row(
            children: [
              const Text('Rota'),
              Switch(
                value: _showHistory,
                onChanged: (v) => setState(() => _showHistory = v),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // ===============================
          // 🧭 SOL PANEL
          // ===============================
          Container(
            width: 320,
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: drivers.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final d = drivers[i];
                final selected = d.driverId == _selectedDriverId;

                return ListTile(
                  selected: selected,
                  selectedTileColor: const Color(0xFFE0F2FE),
                  title: Text(
                    d.plate.isNotEmpty ? d.plate : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: d.name.isNotEmpty ? Text(d.name) : null,
                  trailing: _statusDot(d.status),
                  onTap: () {
                    setState(() => _selectedDriverId = d.driverId);
                    _mapController.move(d.position, 15);
                  },
                );
              },
            ),
          ),

          // ===============================
          // 🗺️ HARİTA
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
                  userAgentPackageName:
                  'com.truck.management.system',
                ),

                if (_showHistory && _selectedDriverId != null)
                  PolylineLayer(
                    polylines: drivers
                        .where((d) =>
                    d.driverId == _selectedDriverId &&
                        d.history.length > 1)
                        .map(
                          (d) => Polyline(
                        points: d.history,
                        strokeWidth: 4,
                        color: const Color(0xFF1E3A5F),
                      ),
                    )
                        .toList(),
                  ),

                MarkerLayer(
                  markers: drivers.map(_marker).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 📍 MARKER
  // ======================================================
  Marker _marker(LiveDriver d) {
    final selected = d.driverId == _selectedDriverId;

    return Marker(
      width: 140,
      height: 90,
      point: d.position,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedDriverId = d.driverId);
          _mapController.move(d.position, 15);
        },
        child: Column(
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1E3A5F)
                      : Colors.transparent,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: Text(
                d.plate.isNotEmpty ? d.plate : '—',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
            if (d.name.isNotEmpty)
              Text(d.name, style: const TextStyle(fontSize: 10)),
            const SizedBox(height: 4),
            Transform.rotate(
              angle: d.heading * pi / 180,
              child: Icon(
                Icons.navigation,
                size: 26,
                color: d.isMoving ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusDot(String status) {
    Color c;
    switch (status) {
      case 'online':
        c = Colors.green;
        break;
      case 'busy':
        c = Colors.orange;
        break;
      default:
        c = Colors.red;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

// ======================================================
// MODELS
// ======================================================
class LiveDriver {
  final String driverId;
  final String plate;
  final String name;
  final LatLng position;
  final double heading;
  final bool isMoving;
  final String status;
  final List<LatLng> history;

  LiveDriver({
    required this.driverId,
    required this.plate,
    required this.name,
    required this.position,
    required this.heading,
    required this.isMoving,
    required this.status,
    required this.history,
  });
}
