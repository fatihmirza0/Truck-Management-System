// 📁 lib/screens/commons/login/widgets/login_desktop_panel.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';

class LoginDesktopPanel extends StatelessWidget {
  final bool withAnimation;
  final VoidCallback? onSecretTap;

  const LoginDesktopPanel({
    super.key,
    this.withAnimation = false,
    this.onSecretTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(right: 40),
      child: Column(
        children: [
          GestureDetector(
            onTap: onSecretTap,
            child: Transform.rotate(
              angle: -math.pi / 12,
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 120,
              ),
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
    );

    return Expanded(
      child: withAnimation
          ? SlideInWidget(
              delay: const Duration(milliseconds: 100),
              begin: const Offset(-0.3, 0),
              child: content,
            )
          : content,
    );
  }
}
