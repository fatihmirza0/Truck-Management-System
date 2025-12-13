import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../login_screen.dart';
import '../profile_screen.dart';
import 'jobs/jobs_page.dart';
import 'add_user_page.dart';
import 'users_page.dart';
import 'report_Screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  static const Color accent = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color sidebar = Color(0xFF0F172A);

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _index = 0;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  final List<Widget> _pages = const [
    JobsPage(),
    AddUserPage(),
    UsersPage(),
    ReportScreen(),
  ];

  final List<String> _titles = [
    "İş Yönetimi",
    "Personel Ekle",
    "Kullanıcılar",
    "Raporlar",
  ];

  final List<String> _subTitles = [
    "Görevler",
    "Yeni Kullanıcı",
    "Kullanıcı Listesi",
    "İş Raporları",
  ];

  final List<IconData> _icons = [
    Icons.dashboard_customize_outlined,
    Icons.person_add_outlined,
    Icons.people_alt_outlined,
    Icons.bar_chart_outlined,
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

    return isDesktop ? _desktopLayout() : _mobileLayout();
  }

  // ======================================================
  // 📱 MOBILE LAYOUT
  // ======================================================
  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ManagerScreen.accent,
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
          _profileButton(isDesktop: false),
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
        selectedItemColor: ManagerScreen.accent,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined),
            label: "İşler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            label: "Ekle",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: "Kullanıcılar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: "Rapor",
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 🖥️ DESKTOP LAYOUT
  // ======================================================
  Widget _desktopLayout() {
    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 280,
            color: ManagerScreen.sidebar,
            child: Column(
              children: [
                const SizedBox(height: 32),
                _sidebarHeader(),
                const SizedBox(height: 32),
                _menuItem("İş Yönetimi", Icons.dashboard_customize_outlined, 0),
                _menuItem("Personel Ekle", Icons.person_add_outlined, 1),
                _menuItem("Kullanıcılar", Icons.people_alt_outlined, 2),
                _menuItem("Raporlar", Icons.bar_chart_outlined, 3),
                const Spacer(),
                _sidebarProfile(),
              ],
            ),
          ),

          // CONTENT
          Expanded(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _pages[_index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // SIDEBAR WIDGETS
  // ======================================================
  Widget _sidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ManagerScreen.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            "Yönetim Paneli",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarProfile() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.account_circle, color: Colors.white70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              FirebaseAuth.instance.currentUser?.email ?? "",
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _profileButton(isDesktop: true),
        ],
      ),
    );
  }

  Widget _menuItem(String text, IconData icon, int idx) {
    final selected = _index == idx;

    return InkWell(
      onTap: () => setState(() => _index = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? ManagerScreen.accent.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected
                    ? ManagerScreen.accent
                    : Colors.white54),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // TOP BAR
  // ======================================================
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          Icon(_icons[_index], color: ManagerScreen.accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[_index],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _subTitles[_index],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================================================
  // PROFILE BUTTON
  // ======================================================
  Widget _profileButton({required bool isDesktop}) {
    return IconButton(
      icon: Icon(
        Icons.person_outline,
        color: isDesktop ? Colors.white : ManagerScreen.accent,
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      },
    );
  }
}
