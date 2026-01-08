// 📁 lib/screens/driver/completed_job_detail/widgets/detail_card.dart
import 'package:flutter/material.dart';

class DetailCard extends StatelessWidget {
  final Widget child;

  const DetailCard({
    super.key,
    required this.child,
  });

  static const Color border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}


