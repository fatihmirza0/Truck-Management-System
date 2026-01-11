// 📁 lib/screens/driver/active_jobs/widgets/active_jobs_header.dart
import 'package:flutter/material.dart';

class ActiveJobsHeader extends StatelessWidget {
  const ActiveJobsHeader({super.key});

  static const Color primary = Color(0xFF1E3A5F);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Aktif İş",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              "Üzerinizde bulunan aktif sevkiyat bilgileri",
              style: TextStyle(
                fontSize: 14,
                color: textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}



