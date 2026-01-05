// 📁 lib/pages/widgets/driver_selection_card.dart
import 'package:flutter/material.dart';

class DriverSelectionCard extends StatelessWidget {
  final Map<String, dynamic>? selectedDriver;
  final VoidCallback onTap;

  const DriverSelectionCard({
    super.key,
    required this.selectedDriver,
    required this.onTap,
  });

  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selectedDriver == null ? cardBg : accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedDriver == null ? border : accent,
            width: selectedDriver == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedDriver == null ? bg : accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selectedDriver == null ? Icons.person_add_outlined : Icons.person,
                color: selectedDriver == null ? textSecondary : accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectedDriver == null
                  ? const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Şoför Seç",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Göreve atanacak şoförü seçin",
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedDriver!['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedDriver!['email'] ?? '-',
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selectedDriver == null ? Icons.arrow_forward_ios : Icons.check_circle,
              color: selectedDriver == null ? textSecondary : success,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}