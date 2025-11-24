import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../login_screen.dart';
import 'jobs_page.dart';
import 'add_user_page.dart';
import 'users_page.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  int _selectedIndex = 0;
  String? managerId;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    managerId = user?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (managerId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return isDesktop ? _desktop() : _mobile();
  }

  //-------------------------------------
  // 📱 MOBILE LAYOUT
  //-------------------------------------
  Widget _mobile() {
    final pages = [
      JobsPage(managerId: managerId!),
      const AddUserPage(),
      const UsersPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        title: const Column(
          children: [
            Text(
              "Truck Management System",
              style: TextStyle(
                color: Color(0xFF1E2A3A),
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Yönetim Paneli",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          _buildLogoutButton(isDesktop: false), // Mobilde sadece ikon
        ],
        iconTheme: const IconThemeData(color: Colors.grey),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: "İşler"),
          BottomNavigationBarItem(icon: Icon(Icons.person_add), label: "Ekle"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Kullanıcılar"),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }

  //-------------------------------------
  // 🖥️ DESKTOP LAYOUT
  //-------------------------------------
  Widget _desktop() {
    final pages = [
      JobsPage(managerId: managerId!),
      const AddUserPage(),
      const UsersPage(),
    ];

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: const Color(0xFF1E2A3A),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Yönetim Paneli",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 30),
                _menuItem("İş Yönetimi", Icons.assignment, 0),
                _menuItem("Personel Ekle", Icons.group_add, 1),
                _menuItem("Kullanıcılar", Icons.people, 2),
                const Spacer(),
                _buildLogoutButton(isDesktop: true), // Desktop uyumlu
                const SizedBox(height: 20),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              color: const Color(0xFFF7F8FA),
              child: pages[_selectedIndex],
            ),
          )
        ],
      ),
    );
  }

  //-------------------------------------
  // MENU ITEM
  //-------------------------------------
  Widget _menuItem(String label, IconData icon, int index) {
    bool selected = _selectedIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(selected ? 1 : 0.7)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(selected ? 1 : 0.7),
                fontSize: 15,
              ),
            )
          ],
        ),
      ),
    );
  }

  //-------------------------------------
  // LOGOUT BUTTON
  //-------------------------------------
  Widget _buildLogoutButton({required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _logoutDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  //-------------------------------------
  // LOGOUT DIALOG
  //-------------------------------------
  void _logoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Çıkış Yap"),
        content: const Text("Çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Evet",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
        );
      }
    }
  }
}
