// 📁 lib/screens/driver/completed_job_detail/widgets/detail_section_title.dart
import 'package:flutter/material.dart';

class DetailSectionTitle extends StatelessWidget {
  final String text;

  const DetailSectionTitle({
    super.key,
    required this.text,
  });

  static const Color textDark = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
    );
  }
}



