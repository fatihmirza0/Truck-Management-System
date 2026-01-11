// 📁 lib/screens/driver/active_jobs/widgets/info_row.dart
import 'package:flutter/material.dart';

class InfoRow extends StatelessWidget {
  final String label;
  final String? value;

  const InfoRow({
    super.key,
    required this.label,
    this.value,
  });

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            (value == null || value!.trim().isEmpty) ? "-" : value!,
            style: const TextStyle(
              fontSize: 14,
              color: textDark,
            ),
          ),
        ),
      ],
    );
  }
}



