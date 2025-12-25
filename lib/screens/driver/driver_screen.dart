import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'active_jobs_page.dart';
import 'completed_jobs_page.dart';
import '../commons/login_screen.dart';
import '../commons/profile_screen.dart';
import 'package:lojistik/services/driver_location_service.dart';

class DriverScreen extends StatefulWidget {
  final String uid;

  const DriverScreen({super.key, required this.uid});

  static const Color accent = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  late DriverLocationService _locationService;
  bool _isTrackingActive = false;

  late final List<Widget> _pages = [
    ActiveJobsPage(uid: widget.uid),
    CompletedJobsPage(uid: widget.uid),
  ];

  final List<String> _titles = [
    "Aktif İş",
    "Tamamlanan İşler",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService = DriverLocationService(widget.uid);
    _startLocationTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationService.stopTracking();
    _locationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama background'a gitse bile tracking devam etsin
    if (state == AppLifecycleState.resumed) {
      // Foreground'a döndüğünde kontrol et
      if (!_locationService.isTracking) {
        _startLocationTracking();
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
      if (mounted) {
        setState(() {
          _isTrackingActive = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Konum takibi aktif'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Location tracking error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Konum izni hatası: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Ayarlar',
              textColor: Colors.white,
              onPressed: () {
                // Kullanıcıyı ayarlara yönlendir
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (_isTrackingActive) {
      // Stop tracking
      await _locationService.stopTracking();
      if (mounted) {
        setState(() {
          _isTrackingActive = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.location_off, color: Colors.white),
                SizedBox(width: 12),
                Text('Konum takibi durduruldu'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Start tracking
      await _startLocationTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.microtask(() {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: DriverScreen.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: DriverScreen.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Truck Management",
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        _titles[_index],
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tracking indicator with animation
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isTrackingActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: _isTrackingActive
                              ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isTrackingActive ? 'Aktif' : 'Pasif',
                        style: TextStyle(
                          color: _isTrackingActive
                              ? Colors.green
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Location info button
          if (_isTrackingActive && _locationService.lastPosition != null)
            Tooltip(
              message: 'Konum Bilgisi',
              child: IconButton(
                icon: Icon(
                  _locationService.isMoving
                      ? Icons.directions_car
                      : Icons.stop_circle,
                  color: _locationService.isMoving
                      ? Colors.green
                      : Colors.orange,
                ),
                onPressed: () {
                  _showLocationInfo();
                },
              ),
            ),
          // Location tracking toggle
          Tooltip(
            message: _isTrackingActive
                ? "Konum Takibini Durdur"
                : "Konum Takibini Başlat",
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: _isTrackingActive
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  _isTrackingActive ? Icons.location_on : Icons.location_off,
                  color:
                  _isTrackingActive ? Colors.green : const Color(0xFF64748B),
                ),
                onPressed: _toggleLocationTracking,
              ),
            ),
          ),
          // Profile
          IconButton(
            icon: const Icon(
              Icons.person_outline,
              color: DriverScreen.accent,
            ),
            tooltip: "Profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: DriverScreen.accent,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: "Aktif İş",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: "Tamamlananlar",
          ),
        ],
      ),
    );
  }

  void _showLocationInfo() {
    final pos = _locationService.lastPosition;
    if (pos == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFF1E3A5F)),
            SizedBox(width: 8),
            Text('Konum Bilgisi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Durum',
                _locationService.isMoving ? 'Hareket Halinde' : 'Durgun'),
            _infoRow('Hız', '${(pos.speed * 3.6).toStringAsFixed(1)} km/h'),
            _infoRow('Yön', '${pos.heading.toStringAsFixed(0)}°'),
            _infoRow('Doğruluk', '±${pos.accuracy.toStringAsFixed(0)}m'),
            _infoRow(
              'Koordinat',
              '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}