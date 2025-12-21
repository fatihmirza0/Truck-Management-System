import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'active_jobs_page.dart';
import 'completed_jobs_page.dart';
import '../login_screen.dart';
import '../profile_screen.dart';

class DriverScreen extends StatefulWidget {
  final String uid;

  const DriverScreen({super.key, required this.uid});

  // ManagerScreen ile aynı tokenlar
  static const Color accent = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  int _index = 0;

  late final List<Widget> _pages = [
    ActiveJobsPage(uid: widget.uid),
    CompletedJobsPage(uid: widget.uid),
  ];

  final List<String> _titles = [
    "Aktif İş",
    "Tamamlanan İşler",
  ];

  final List<IconData> _icons = [
    Icons.work_outline,
    Icons.check_circle_outline,
  ];

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

      // ======================================================
      // APP BAR (ManagerScreen MOBILE ile aynı stil)
      // ======================================================
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
                Text(
                  _titles[_index],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
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

      // ======================================================
      // BODY
      // ======================================================
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),

      // ======================================================
      // BOTTOM NAV (Kurumsal, sade)
      // ======================================================
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
