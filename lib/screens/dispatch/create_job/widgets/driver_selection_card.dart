// 📁 lib/pages/widgets/driver_selection_card.dart
import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';

class DriverSelectionCard extends StatelessWidget {
  final Map<String, dynamic>? selectedDriver;
  final VoidCallback onTap;

  const DriverSelectionCard({
    super.key,
    required this.selectedDriver,
    required this.onTap,
  });

  // Renkler AppTheme'den kullanılacak

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      onTap: onTap,
      color: selectedDriver == null
          ? Colors.white
          : AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedDriver == null
                ? const Color(0xFFE2E8F0)
                : AppTheme.primaryColor,
            width: selectedDriver == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedDriver == null
                    ? AppTheme.backgroundColor
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selectedDriver == null
                    ? Icons.person_add_outlined
                    : Icons.person,
                color: selectedDriver == null
                    ? AppTheme.textSecondary
                    : AppTheme.primaryColor,
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
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Göreve atanacak şoförü seçin",
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
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
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedDriver!['email'] ?? '-',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
            ),
            Icon(
              selectedDriver == null
                  ? Icons.arrow_forward_ios
                  : Icons.check_circle,
              color: selectedDriver == null
                  ? AppTheme.textSecondary
                  : const Color(0xFF10B981),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
