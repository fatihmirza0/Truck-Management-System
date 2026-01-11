import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_job/pages/create_job_page.dart';
import 'add_driver/pages/add_driver_page.dart';
import 'dispatch_jobs/pages/dispatch_jobs_page.dart';
import 'package:lojistik/screens/commons/profile/pages/profile_screen.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/utils/page_transitions.dart';

class DispatchMainScreen extends StatefulWidget {
  final String uid;

  const DispatchMainScreen({super.key, required this.uid});

  @override
  State<DispatchMainScreen> createState() => _DispatchMainScreenState();
}

class _DispatchMainScreenState extends State<DispatchMainScreen> {
  // ==========================================================
  // SIDEBAR STATE
  // ==========================================================
  bool _sidebarOpen = true;

  bool get showText => _sidebarOpen;

  double get sidebarWidth => _sidebarOpen ? 260.0 : 72.0;

  static const Duration animDuration = Duration(milliseconds: 150);
  static const Curve animCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  // ==========================================================
  // APP STATE
  // ==========================================================
  int _index = 0;
  bool loading = true;

  String? userName;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  // ==========================================================
  // UI TOKENS
  // ==========================================================
  // Renkler AppTheme'den kullanılacak

  // ==========================================================
  // INIT
  // ==========================================================
  @override
  void initState() {
    super.initState();
    _loadDispatchUser();
  }

  Future<void> _loadDispatchUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap =
        await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (snap.exists) {
      userName = snap.data()?["name"] ?? "Kullanıcı";
    }

    setState(() => loading = false);
  }

  // ==========================================================
  // DATA
  // ==========================================================
  final List<Widget> _pages = const [
    CreateJobPage(),
    AddDriverPage(),
    DispatchJobsPage(),
  ];

  final List<String> _titles = [
    "Yeni İş Oluştur",
    "Şoför Ekle",
    "İş Takibi",
  ];

  final List<String> _subTitles = [
    "Görev",
    "Personel",
    "Tüm İşler",
  ];

  final List<IconData> _icons = [
    Icons.assignment_outlined,
    Icons.person_add_outlined,
    Icons.work_outline,
  ];

  // ==========================================================
  // ACTIONS
  // ==========================================================
  void _openProfile() {
    Navigator.push(
      context,
      SlidePageRoute(page: const ProfileScreen()),
    ).then((_) => _loadDispatchUser());
  }

  // ==========================================================
  // BUILD
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
      );
    }

    return isDesktop ? _desktopLayout() : _mobileLayout();
  }

  // ==========================================================
  // MOBILE
  // ==========================================================
  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_titles[_index],
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon:
                const Icon(Icons.person_outline, color: AppTheme.primaryColor),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textTertiary,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined), label: "İş"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_add_outlined), label: "Şoför"),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline), label: "İşler"),
        ],
      ),
    );
  }

  // ==========================================================
  // DESKTOP
  // ==========================================================
  Widget _desktopLayout() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // CONTENT
          AnimatedPositioned(
            duration: animDuration,
            curve: animCurve,
            left: sidebarWidth,
            right: 0,
            top: 0,
            bottom: 0,
            child: Column(
              children: [
                _topBar(),
                Expanded(child: _pages[_index]),
              ],
            ),
          ),

          // SIDEBAR
          AnimatedPositioned(
            duration: animDuration,
            curve: animCurve,
            left: 0,
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: Container(
              color: AppTheme.sidebarColor,
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
                  const SizedBox(height: 24),
                  _sidebarHeader(),
                  const SizedBox(height: 32),
                  _menuItem("İş Oluştur", Icons.assignment_outlined, 0),
                  _menuItem("Şoför Ekle", Icons.person_add_outlined, 1),
                  _menuItem("İş Takibi", Icons.work_outline, 2),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _sidebarOpen
                        ? _profileCard()
                        : IconButton(
                            onPressed: _openProfile,
                            icon: const Icon(Icons.person, color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // COMPONENTS
  // ==========================================================
  Widget _sidebarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: showText ? Alignment.centerLeft : Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min, // 🔥 KRİTİK
          children: showText
              ? [
                  _squareIcon(Icons.local_shipping_outlined),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Dispatch Paneli",
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

    return ScaleButton(
      onTap: () => setState(() => _index = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment:
              showText ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: showText
              ? [
                  Icon(icon,
                      color: selected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ]
              : [
                  Icon(icon,
                      color: selected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.6)),
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
          Icon(_icons[_index], color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[_index],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              Text(_subTitles[_index],
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return AnimatedCard(
      onTap: _openProfile,
      color: Colors.white.withValues(alpha: 0.1),
      child: Container(
        padding: EdgeInsets.all(showText ? 12 : 10),
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
                            color: AppTheme.textTertiary,
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
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
