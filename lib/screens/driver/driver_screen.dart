import 'package:flutter/material.dart';
import 'active_jobs_page.dart';
import 'completed_jobs_page.dart';

class DriverScreen extends StatefulWidget {
  final String driverId;

  const DriverScreen({super.key, required this.driverId});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ActiveJobsPage(driverId: widget.driverId),
      CompletedJobsPage(driverId: widget.driverId),
    ];

    return Scaffold(
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
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Şoför Paneli",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: "Aktif İş",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: "Tamamlananlar",
          ),
        ],
      ),
    );
  }
}
