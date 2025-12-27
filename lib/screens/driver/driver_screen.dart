import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

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

  /// Firestore → iş durumu
  String _jobStatus = 'available'; // available | busy

  /// RTDB → canlılık
  String _rtdbStatus = 'offline'; // online | offline

  bool _isTrackingActive = false;

  StreamSubscription<DocumentSnapshot>? _jobStatusListener;
  StreamSubscription<DatabaseEvent>? _rtdbStatusListener;

  /// ✅ SON DURUM (UI bunu kullanır)
  String get _finalStatus =>
      _jobStatus == 'busy' ? 'busy' : _rtdbStatus;

  late final List<Widget> _pages = [
    ActiveJobsPage(uid: widget.uid),
    CompletedJobsPage(uid: widget.uid),
  ];

  final List<String> _titles = [
    "Aktif İş",
    "Tamamlanan İşler",
  ];

  // ---------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationService = DriverLocationService(widget.uid);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _jobStatusListener?.cancel();
    _rtdbStatusListener?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _jobStatus == 'busy' &&
        !_locationService.isTracking) {
      _startLocationTracking();
    }
  }

  // ---------------------------------------------------
  // INIT
  // ---------------------------------------------------

  Future<void> _initialize() async {
    try {
      /// 🔥 Firestore jobStatus
      _jobStatusListener = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots()
          .listen((snap) {
        if (!snap.exists || !mounted) return;
        setState(() {
          _jobStatus = snap.data()?['jobStatus'] ?? 'available';
        });
      });

      /// 🔥 RTDB online / offline
      _rtdbStatusListener = FirebaseDatabase.instance
          .ref()
          .child('driver_locations')
          .child(widget.uid)
          .child('status')
          .onValue
          .listen((event) {
        if (!mounted) return;

        final data = event.snapshot.value as Map?;
        final status = data?['status'] ?? 'offline';

        setState(() {
          _rtdbStatus = status;
          _isTrackingActive = status == 'online';
        });
      });

      /// İlk açılışta tracking başlat
      await _startLocationTracking();
    } catch (e) {
      debugPrint('❌ Init error: $e');
    }
  }

  // ---------------------------------------------------
  // TRACKING
  // ---------------------------------------------------

  Future<void> _startLocationTracking() async {
    try {
      await _locationService.startTracking();
      if (mounted) {
        setState(() => _isTrackingActive = true);
      }
    } catch (e) {
      debugPrint('❌ Start tracking error: $e');
    }
  }

  Future<void> _stopLocationTracking() async {
    if (_jobStatus == 'busy') {
      _showBusyWarning();
      return;
    }

    try {
      await _locationService.stopTracking();
      if (mounted) {
        setState(() => _isTrackingActive = false);
      }
    } catch (e) {
      debugPrint('❌ Stop tracking error: $e');
    }
  }

  // ---------------------------------------------------
  // UI
  // ---------------------------------------------------

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: DriverScreen.bg,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------

  AppBar _buildAppBar() {
    return AppBar(
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
            child: const Icon(Icons.local_shipping, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Truck Management",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Text(
                    _titles[_index],
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  _statusDot(),
                ],
              ),
            ],
          )
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isTrackingActive
                ? Icons.location_on
                : Icons.location_off,
            color: _getStatusColor(_finalStatus),
          ),
          onPressed: () {
            _isTrackingActive
                ? _stopLocationTracking()
                : _startLocationTracking();
          },
        ),
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _statusDot() {
    return Row(
      children: [
        const SizedBox(width: 6),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(_finalStatus),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          _getStatusLabel(_finalStatus),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(_finalStatus),
          ),
        ),
      ],
    );
  }

  BottomNavigationBar _buildBottomBar() {
    return BottomNavigationBar(
      currentIndex: _index,
      onTap: (i) => setState(() => _index = i),
      selectedItemColor: DriverScreen.accent,
      unselectedItemColor: const Color(0xFF94A3B8),
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
    );
  }

  // ---------------------------------------------------
  // HELPERS
  // ---------------------------------------------------

  Color _getStatusColor(String status) {
    switch (status) {
      case 'busy':
        return Colors.orange;
      case 'online':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'busy':
        return 'MEŞGUL';
      case 'online':
        return 'AKTİF';
      default:
        return 'PASİF';
    }
  }

  void _showBusyWarning() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Konum Takibi Gerekli"),
        content: const Text(
            "Aktif iş varken konum takibi kapatılamaz."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }
}
