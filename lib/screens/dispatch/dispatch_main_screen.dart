import 'package:flutter/material.dart';
import 'add_driver_page.dart';
import 'create_job_page.dart';

class DispatchMainScreen extends StatefulWidget {
  const DispatchMainScreen({super.key});

  @override
  State<DispatchMainScreen> createState() => _DispatchMainScreenState();
}

class _DispatchMainScreenState extends State<DispatchMainScreen> {
  int _currentIndex = 0;

  final _pages = [
    const CreateJobPage(),
    const AddDriverPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Icon(
            Icons.local_shipping_outlined,
            color: Color(0xFF1E2A3A),
            size: 26,
          ),
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
              "Dispatch Paneli",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),

      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: "İş Oluştur",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: "Şoför Ekle",
          ),
        ],
      ),
    );
  }
}
