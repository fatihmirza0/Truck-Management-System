import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../login_screen.dart';
import 'jobs/jobs_page.dart';
import 'add_user_page.dart';
import 'users_page.dart';
import 'report_Screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  static const Color accent = Color(0xFF2563EB);
  static const Color bg = Color(0xFFF3F4F6);
  static const Color sidebar = Color(0xFF111827);

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _index = 0;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  // ------------------------------------------------------------
  // SAYFALAR
  // ------------------------------------------------------------
  List<Widget> get _pages => const [
    JobsPage(),
    AddUserPage(),
    UsersPage(),
    ReportScreen(),
  ];

  List<String> get _titles => [
    "İş Yönetimi",
    "Personel Ekle",
    "Kullanıcılar",
    "Raporlar",
  ];

  List<String> get _subTitles => [
    "Görevler",
    "Yeni Kullanıcı",
    "Kullanıcı Listesi",
    "İş Raporları",
  ];

  List<IconData> get _icons => [
    Icons.dashboard_customize,
    Icons.person_add,
    Icons.people_alt,
    Icons.bar_chart,
  ];

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // Eğer kullanıcı login değilse → Login ekranına at
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

  // ------------------------------------------------------------
  // 📱 MOBILE UI
  // ------------------------------------------------------------
  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.6,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Truck Management",
              style: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              "Yönetim Paneli",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          _logoutButton(isDesktop: false),
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
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined),
            activeIcon: Icon(Icons.dashboard_customize),
            label: "İşler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            activeIcon: Icon(Icons.person_add),
            label: "Ekle",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            activeIcon: Icon(Icons.people_alt),
            label: "Kullanıcılar",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: "Rapor",
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // 🖥️ DESKTOP UI
  // ------------------------------------------------------------
  Widget _desktopLayout() {
    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      body: Row(
        children: [
          // ==== LEFT SIDEBAR ====
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: ManagerScreen.sidebar,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo / Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: const [
                      Icon(Icons.manage_accounts, color: Colors.white, size: 26),
                      SizedBox(width: 10),
                      Text(
                        "Yönetim Paneli",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    "Truck Management System",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                _menuItem("İş Yönetimi", Icons.dashboard_customize_outlined, 0),
                _menuItem("Personel Ekle", Icons.person_add_outlined, 1),
                _menuItem("Kullanıcılar", Icons.people_alt_outlined, 2),
                _menuItem("Raporlar", Icons.bar_chart, 3),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 60),
                  child: _logoutButton(isDesktop: true),
                ),
              ],
            ),
          ),

          // ==== PAGE BODY ====
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _titles[_index],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: ManagerScreen.accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _icons[_index],
                              size: 16,
                              color: ManagerScreen.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _subTitles[_index],
                              style: const TextStyle(
                                fontSize: 12,
                                color: ManagerScreen.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    color: ManagerScreen.bg,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _pages[_index],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SIDEBAR ITEM
  // ------------------------------------------------------------
  Widget _menuItem(String text, IconData icon, int idx) {
    final selected = _index == idx;

    return InkWell(
      onTap: () => setState(() => _index = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? ManagerScreen.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: Colors.white.withOpacity(selected ? 1 : 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(selected ? 1 : 0.8),
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------
  Widget _logoutButton({required bool isDesktop}) {
    return InkWell(
      borderRadius: BorderRadius.circular(90),
      onTap: _confirmLogout,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.logout, color: Colors.redAccent),
          if (isDesktop) ...[
            const SizedBox(width: 10),
            const Text(
              "Çıkış",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Oturumu Kapat"),
        content: const Text("Hesabınızdan çıkış yapmak istiyor musunuz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );

    if (res == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    }
  }
}
