import 'package:flutter/material.dart';
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

  final List<Widget> _pages = const [
    JobsPage(),
    AddUserPage(),
    UsersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(Icons.local_shipping_outlined,
              color: Color(0xFF1E2A3A), size: 26),
        ),
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
}
