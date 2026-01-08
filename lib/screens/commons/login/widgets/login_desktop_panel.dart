// 📁 lib/screens/commons/login/widgets/login_desktop_panel.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class LoginDesktopPanel extends StatelessWidget {
  const LoginDesktopPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 40),
        child: Column(
          children: [
            Transform.rotate(
              angle: -math.pi / 12,
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 120,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Truck Management System",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Kurumsal Araç Takip ve İş Yönetimi",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


