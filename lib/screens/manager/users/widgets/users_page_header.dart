// 📁 lib/screens/manager/users/widgets/users_page_header.dart
import 'package:flutter/material.dart';

class UsersPageHeader extends StatelessWidget {
  final bool isDesktop;

  const UsersPageHeader({
    super.key,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.people_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Kullanıcı Yönetimi",
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Şoför ve dispatch kullanıcılarını yönetin",
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



