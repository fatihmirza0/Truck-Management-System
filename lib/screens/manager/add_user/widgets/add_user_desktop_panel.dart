// 📁 lib/screens/manager/add_user/widgets/add_user_desktop_panel.dart
import 'package:flutter/material.dart';
import 'add_user_info_box.dart';

class AddUserDesktopPanel extends StatelessWidget {
  final Widget child;

  const AddUserDesktopPanel({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings, size: 42, color: Colors.white),
          const SizedBox(height: 18),
          const Text(
            "Yönetici Kullanıcı Oluşturma",
            style: TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Sisteme yeni sürücü veya dispatch ekleyin.",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: .85),
            ),
          ),
          const Spacer(),
          const AddUserInfoBox(),
        ],
      ),
    );
  }
}



