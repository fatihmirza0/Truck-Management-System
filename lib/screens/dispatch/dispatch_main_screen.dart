import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_job_page.dart';
import 'add_driver_page.dart';
import 'dispatch_wait_reject_page.dart';
import 'dispatch_active_completed_page.dart';

class DispatchMainScreen extends StatefulWidget {
  const DispatchMainScreen({super.key});

  @override
  State<DispatchMainScreen> createState() => _DispatchMainScreenState();
}

class _DispatchMainScreenState extends State<DispatchMainScreen> {
  int _index = 0;

  bool get isDesktop => MediaQuery.of(context).size.width >= 900;

  static const Color bg = Color(0xFFF3F4F6);
  static const Color sidebar = Color(0xFF111827);
  static const Color accent = Color(0xFF2563EB);

  String? dispatchId;
  bool loading = true;

  // ---------------------------------------------------------------------------
  // DISPATCH ID YÜKLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadDispatchId();
  }

  Future<void> _loadDispatchId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snap = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    dispatchId = snap.data()?["dispatchId"];

    setState(() => loading = false);
  }

  // ---------------------------------------------------------------------------
  // SAYFALAR
  // ---------------------------------------------------------------------------
  List<Widget> get pages => [
    const CreateJobPage(),
    const AddDriverPage(),
    DispatchWaitRejectPage(dispatchId: dispatchId!),
    DispatchActiveCompletedPage(dispatchId: dispatchId!),
  ];

  List<String> get titles => [
    "Yeni İş Oluştur",
    "Şoför Ekle",
    "Bekleyen & Reddedilen",
    "Aktif & Tamamlanan",
  ];

  List<String> get subTitles => [
    "Görev",
    "Personel",
    "İş Durumu",
    "İş Durumu",
  ];

  List<IconData> get icons => [
    Icons.assignment,
    Icons.person_add,
    Icons.watch_later_outlined,
    Icons.check_circle_outline,
  ];

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return isDesktop ? _desktop() : _mobile();
  }

  // ---------------------------------------------------------------------------
  // 📱 MOBILE UI
  // ---------------------------------------------------------------------------
  Widget _mobile() {
    return Scaffold(
      backgroundColor: bg,
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
              "Dispatch Paneli",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          _logoutBtn(isDesktop: false),
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
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.watch_later_outlined),
            activeIcon: Icon(Icons.watch_later),
            label: "Bekleyen",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: "Aktif",
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥️ DESKTOP UI
  // ---------------------------------------------------------------------------
  Widget _desktop() {
    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          // ==== LEFT SIDEBAR ====
          Container(
            width: 250,
            decoration: const BoxDecoration(
              color: sidebar,
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

                // LOGO
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: const [
                      Icon(Icons.local_shipping,
                          color: Colors.white, size: 26),
                      SizedBox(width: 10),
                      Text(
                        "Dispatch Paneli",
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

                // MENU ITEMS
                _menu("İş Oluştur", Icons.assignment_outlined, 0),
                _menu("Şoför Ekle", Icons.person_add_outlined, 1),
                _menu("Bekleyen İşler", Icons.watch_later_outlined, 2),
                _menu("Aktif & Tamamlanan", Icons.check_circle_outline, 3),

                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 60),
                  child: _logoutBtn(isDesktop: true),
                ),
              ],
            ),
          ),

          // ==== MAIN CONTENT ====
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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
                        titles[_index],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          children: [
                            Icon(icons[_index], size: 16, color: accent),
                            const SizedBox(width: 6),
                            Text(
                              subTitles[_index],
                              style: const TextStyle(
                                fontSize: 12,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
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

  // ---------------------------------------------------------------------------
  // MENU ITEM
  // ---------------------------------------------------------------------------
  Widget _menu(String text, IconData icon, int idx) {
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
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon,
                color: Colors.white.withOpacity(selected ? 1 : 0.7),
                size: 20),
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

  // ---------------------------------------------------------------------------
  // LOGOUT BUTTON
  // ---------------------------------------------------------------------------
  Widget _logoutBtn({required bool isDesktop}) {
    return InkWell(
      borderRadius: BorderRadius.circular(90),
      onTap: _logoutDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDesktop ? Colors.white.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(90),
        ),
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
              )
            ]
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOGOUT CONFIRM
  // ---------------------------------------------------------------------------
  Future<void> _logoutDialog() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Oturumu Kapat"),
        content: const Text("Hesabınızdan çıkış yapmak istiyor musunuz?"),
        actions: [
          TextButton(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(context, false),
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
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
    }
  }
}
