// 📁 lib/pages/widgets/form_header.dart
import 'package:flutter/material.dart';

class FormHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FormHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static const Color primary = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primary, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}