import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'active_jobs_page.dart';
import 'completed_jobs_page.dart';

class DriverScreen extends StatefulWidget {
  final String uid;

  const DriverScreen({super.key, required this.uid});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ActiveJobsPage(uid: widget.uid),        // 🔥 yeni mimariye uygun
      CompletedJobsPage(uid: widget.uid),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              "Truck Management System",
              style: TextStyle(
                color: Color(0xFF1E2A3A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Şoför Paneli",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: "Çıkış Yap",
            onPressed: _logoutDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
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

  // -------------------------------------------------------
  // 🔥 ÇIKIŞ DİYALOĞU
  // -------------------------------------------------------
  Future<void> _logoutDialog() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Çıkış Yap"),
        content: const Text("Oturumdan çıkmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Evet, Çıkış Yap"),
          ),
        ],
      ),
    );

    if (res == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }
}
