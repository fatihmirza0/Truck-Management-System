import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_job_page.dart';
import 'add_driver_page.dart';
import 'dispatch_jobs_page.dart';
import 'package:lojistik/screens/profile_screen.dart';

class DispatchMainScreen extends StatefulWidget {
  const DispatchMainScreen({super.key, required uid});

  @override
  State<DispatchMainScreen> createState() => _DispatchMainScreenState();
}

class _DispatchMainScreenState extends State<DispatchMainScreen> {
  int _index = 0;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  // 🎨 UI TOKENS
  static const Color accent = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color sidebar = Color(0xFF0F172A);

  String? dispatchUid;
  String? userName;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadDispatchUid();
  }

  Future<void> _loadDispatchUid() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      setState(() => loading = false);
      return;
    }

    final snap =
    await FirebaseFirestore.instance.collection("users").doc(uid).get();

    if (snap.exists && snap.data()?["role"] == "dispatch") {
      dispatchUid = uid;
      userName = snap.data()?["name"] ?? "Kullanıcı";
    }

    setState(() => loading = false);
  }

  List<Widget> get pages => [
    const CreateJobPage(),
    const AddDriverPage(),
    DispatchJobsPage(),
  ];

  List<String> get titles => [
    "Yeni İş Oluştur",
    "Şoför Ekle",
    "İş Takibi",
  ];

  List<String> get subTitles => [
    "Görev",
    "Personel",
    "Tüm İşler",
  ];

  List<IconData> get icons => [
    Icons.assignment_outlined,
    Icons.person_add_outlined,
    Icons.work_outline,
  ];

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    ).then((_) {
      // Profil sayfasından dönünce kullanıcı adını yeniden yükle
      _loadDispatchUid();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return isDesktop ? _desktopLayout() : _mobileLayout();
  }

  // ==========================================================
  // 📱 MOBILE UI
  // ==========================================================
  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: Colors.white,
                size: 18,
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
                  titles[_index],
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
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline, color: Color(0xFF1E3A5F)),
            tooltip: "Profilim",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: pages[_index],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: accent,
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: "İş",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            activeIcon: Icon(Icons.person_add),
            label: "Şoför",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: "İşler",
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 🖥️ DESKTOP UI
  // ==========================================================
  Widget _desktopLayout() {
    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: sidebar,
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // LOGO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dispatch Paneli",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
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

                _menuItem("İş Oluştur", Icons.assignment_outlined, 0),
                _menuItem("Şoför Ekle", Icons.person_add_outlined, 1),
                _menuItem("İş Takibi", Icons.work_outline, 2),

                const Spacer(),

                // Profile Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _profileButton(),
                ),
              ],
            ),
          ),

          // MAIN AREA
          Expanded(
            child: Column(
              children: [
                // HEADER
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icons[_index],
                          color: accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titles[_index],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            subTitles[_index],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: pages[_index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MENU ITEM
  // ==========================================================
  Widget _menuItem(String text, IconData icon, int idx) {
    final selected = _index == idx;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _index = idx),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? accent : Colors.white.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color:
                    selected ? Colors.white : Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // PROFILE BUTTON
  // ==========================================================
  Widget _profileButton() {
    return InkWell(
      onTap: _openProfile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName ?? "Kullanıcı",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    "Profilimi Görüntüle",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withOpacity(0.6),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}