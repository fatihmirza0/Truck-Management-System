// 📁 lib/screens/driver/completed_job_detail/widgets/detail_date_row.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DetailDateRow extends StatelessWidget {
  final String label;
  final DateTime? date;

  const DetailDateRow({
    super.key,
    required this.label,
    this.date,
  });

  static const Color textMuted = Color(0xFF64748B);
  static const Color textDark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              date != null
                  ? DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(date!)
                  : "-",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


