import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lojistik/screens/manager/jobs/completed_jobs_page.dart';

import '../commons/login/pages/login_screen.dart';
import '../commons/live_tracking_screen.dart';
import '../commons/profile/pages/profile_screen.dart';
import '../../config/app_theme.dart';
import '../../widgets/animated/animated_widgets.dart';
import '../../utils/page_transitions.dart';
import 'jobs/pages/jobs_page.dart';
import 'add_user/pages/add_user_page.dart';
import 'users/pages/users_page.dart';
import 'report_screen.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  static const Color accent = AppTheme.primaryColor;
  static const Color bg = AppTheme.backgroundColor;
  static const Color sidebar = AppTheme.sidebarColor;

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _index = 0;
  bool _sidebarOpen = true;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;
  bool get showText => _sidebarOpen;

  String? userName;

  final List<Widget> _pages = const [
    LiveTrackingPanel(),
    JobsPage(),
    CompletedJobsPage(),
    AddUserPage(),
    UsersPage(),
    ReportScreen(),
  ];

  final List<String> _titles = [
    "Canlı Takip",
    "İş Yönetimi",
    "Tamamlanan İşler",
    "Personel Ekle",
    "Kullanıcılar",
    "Raporlar",
  ];

  final List<String> _subTitles = [
    "Rota Konum",
    "Görevler",
    "Filtre & Export",
    "Yeni Kullanıcı",
    "Kullanıcı Listesi",
    "İş Raporları",
  ];

  final List<IconData> _icons = [
    Icons.map_outlined,
    Icons.dashboard_customize_outlined,
    Icons.task_alt_outlined,
    Icons.person_add_outlined,
    Icons.people_alt_outlined,
    Icons.bar_chart_outlined,
  ];

  @override
  void initState() {
    super.initState();
    userName = FirebaseAuth.instance.currentUser?.email;
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

    return isDesktop ? _desktop() : _mobile();
  }

  // ======================================================
  // MOBILE - DRAWER İLE
  // ======================================================
  Widget _mobile() {
    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: ManagerScreen.accent),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ManagerScreen.accent,
                borderRadius: BorderRadius.circular(8),
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
                Text(
                  _titles[_index],
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _subTitles[_index],
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: ManagerScreen.accent),
            onPressed: _openProfile,
          ),
        ],
      ),
      drawer: _mobileDrawer(),
      body: _pages[_index],
      // 🔥 BottomNavigationBar SADECE ÖNEMLİ SAYFALARI GÖSTER
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index > 2 ? 0 : _index, // Drawer'dakiler için 0
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: ManagerScreen.accent,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: "Canlı Takip",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined),
            label: "İşler",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            label: "Tamamlanan",
          ),
        ],
      ),
    );
  }

  // ======================================================
  // MOBILE DRAWER
  // ======================================================
  Widget _mobileDrawer() {
    return Drawer(
      width: 265,
      backgroundColor: ManagerScreen.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ManagerScreen.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Yönetim Paneli",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Truck Management",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Menu Items
            _mobileDrawerItem("Canlı Takip", Icons.map_outlined, 0),
            _mobileDrawerItem(
                "İş Yönetimi", Icons.dashboard_customize_outlined, 1),
            _mobileDrawerItem("Tamamlanan İşler", Icons.task_alt_outlined, 2),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Divider(color: Color(0xFF334155), thickness: 1),
            ),
            _mobileDrawerItem("Personel Ekle", Icons.person_add_outlined, 3),
            _mobileDrawerItem("Kullanıcılar", Icons.people_alt_outlined, 4),
            _mobileDrawerItem("Raporlar", Icons.bar_chart_outlined, 5),
            const Spacer(),
            // Profile
            Padding(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _openProfile();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ManagerScreen.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName ?? "Kullanıcı",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "Profilimi Görüntüle",
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _mobileDrawerItem(String text, IconData icon, int idx) {
    final selected = _index == idx;

    return ScaleButton(
      onTap: () {
        setState(() => _index = idx);
        Navigator.pop(context); // Drawer'ı kapat
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? ManagerScreen.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? ManagerScreen.accent
                  : Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 15,
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: ManagerScreen.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ======================================================
  // DESKTOP
  // ======================================================
  Widget _desktop() {
    final sidebarWidth = _sidebarOpen ? 280.0 : 72.0;

    return Scaffold(
      backgroundColor: ManagerScreen.bg,
      body: Stack(
        children: [
          Positioned.fill(
            left: sidebarWidth,
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: ClipRect(
                    child: _pages[_index],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              color: ManagerScreen.sidebar,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Align(
                    alignment:
                        _sidebarOpen ? Alignment.centerRight : Alignment.center,
                    child: IconButton(
                      icon: Icon(
                        _sidebarOpen ? Icons.chevron_left : Icons.chevron_right,
                        color: Colors.white70,
                      ),
                      onPressed: () =>
                          setState(() => _sidebarOpen = !_sidebarOpen),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sidebarHeader(),
                  const SizedBox(height: 24),
                  _menuItem("Canlı Takip", CupertinoIcons.map, 0),
                  _menuItem(
                      "İş Yönetimi", Icons.dashboard_customize_outlined, 1),
                  _menuItem("Tamamlanan İşler", Icons.task_alt_outlined, 2),
                  _menuItem("Personel Ekle", Icons.person_add_outlined, 3),
                  _menuItem("Kullanıcılar", Icons.people_alt_outlined, 4),
                  _menuItem("Raporlar", Icons.bar_chart_outlined, 5),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: _profileCard(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: showText ? Alignment.centerLeft : Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: showText
              ? [
                  _squareIcon(Icons.local_shipping_outlined),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Yönetim Paneli",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        "Truck Management System",
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ]
              : [
                  _squareIcon(Icons.local_shipping_outlined),
                ],
        ),
      ),
    );
  }

  Widget _menuItem(String text, IconData icon, int idx) {
    final selected = _index == idx;

    return AnimatedCard(
      elevation: 0,
      hoverElevation: selected ? 2 : 4,
      color: selected
          ? ManagerScreen.accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _index = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment:
              showText ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: showText
              ? [
                  Icon(
                    icon,
                    color: selected
                        ? ManagerScreen.accent
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ]
              : [
                  Icon(
                    icon,
                    color: selected
                        ? ManagerScreen.accent
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ],
        ),
      ),
    );
  }

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

  Widget _profileCard() {
    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(showText ? 12 : 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              showText ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: showText
              ? [
                  _squareIcon(Icons.person),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName ?? "Kullanıcı",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          "Profilimi Görüntüle",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              : [
                  _squareIcon(Icons.person),
                ],
        ),
      ),
    );
  }

  Widget _squareIcon(IconData icon) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ManagerScreen.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      SlidePageRoute(page: const ProfileScreen()),
    );
  }
}
