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

class _DriverScreenState extends State<DriverScreen> with WidgetsBindingObserver {
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
    // Uygulama arka plana gitse bile tracking devam etsin
    // Ama battery optimization için bazı durumlarda durdurabiliriz
    if (state == AppLifecycleState.paused) {
      // Arka plana geçti, tracking devam
    } else if (state == AppLifecycleState.resumed) {
      // Ön plana geldi
      if (!_isTrackingActive) {
        _startLocationTracking();
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
      setState(() {
        _isTrackingActive = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum takibi başlatıldı'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("HATAAAAA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum izni hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (_isTrackingActive) {
      await _locationService.stopTracking();
      setState(() {
        _isTrackingActive = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum takibi durduruldu'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
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
            Column(
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
                    // Tracking indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isTrackingActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Location tracking toggle button
          IconButton(
            icon: Icon(
              _isTrackingActive ? Icons.location_on : Icons.location_off,
              color: _isTrackingActive ? Colors.green : Colors.grey,
            ),
            tooltip: _isTrackingActive ? "Konum Takibini Durdur" : "Konum Takibini Başlat",
            onPressed: _toggleLocationTracking,
          ),
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
}