// 📁 lib/screens/driver/completed_jobs/widgets/completed_jobs_search.dart
import 'package:flutter/material.dart';

class CompletedJobsSearch extends StatelessWidget {
  final TextEditingController controller;

  const CompletedJobsSearch({
    super.key,
    required this.controller,
  });

  static const Color border = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: "Yükleme veya varış limanı ara",
          prefixIcon: Icon(Icons.search, color: textMuted),
          border: InputBorder.none,
        ),
      ),
    );
  }
}


