import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'jobs_page.dart';
import 'add_user_page.dart';
import 'users_page.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fadeController;

  bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;

  final List<Widget> _pages = const [
    JobsPage(),
    AddUserPage(),
    UsersPage(),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }

  // -------------------------------
  //  📱 MOBİL LAYOUT
  // -------------------------------
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
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
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: "Çıkış Yap",
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _pages[_selectedIndex],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1E2A3A),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _fadeController.forward(from: 0);
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: "İş Yönetimi"),
          BottomNavigationBarItem(
              icon: Icon(Icons.group_add), label: "Personel Ekle"),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt), label: "Kullanıcılar"),
        ],
      ),
    );
  }

  // -------------------------------
  //  🖥️ DESKTOP (WINDOWS) LAYOUT
  // -------------------------------
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Row(
        children: [
          // Sol Menü
          Container(
            width: 220,
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "Truck Management System",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2A3A),
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuItem(Icons.assignment, "İş Yönetimi", 0),
                _buildMenuItem(Icons.group_add, "Personel Ekle", 1),
                _buildMenuItem(Icons.people_alt, "Kullanıcılar", 2),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text("Çıkış Yap",
                      style: TextStyle(color: Colors.redAccent)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Sağ sayfa alanı
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, int index) {
    bool isSelected = index == _selectedIndex;

    return InkWell(
      onTap: () {
        setState(() => _selectedIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: isSelected ? const Color(0xFFE9EEF5) : Colors.transparent,
        child: Row(
          children: [
            Icon(icon,
                color:
                isSelected ? const Color(0xFF1E2A3A) : Colors.grey.shade700),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                isSelected ? const Color(0xFF1E2A3A) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
