// 📁 lib/pages/widgets/vehicle_selection_card.dart
import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/models/vehicle_model.dart';

class VehicleSelectionCard extends StatelessWidget {
  final Vehicle? selectedVehicle;
  final VoidCallback onTap;

  const VehicleSelectionCard({
    super.key,
    required this.selectedVehicle,
    required this.onTap,
  });

  // Renkler AppTheme'den kullanılacak

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      onTap: onTap,
      color: selectedVehicle == null
          ? Colors.white
          : AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedVehicle == null
                ? const Color(0xFFE2E8F0)
                : AppTheme.primaryColor,
            width: selectedVehicle == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedVehicle == null
                    ? AppTheme.backgroundColor
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selectedVehicle == null
                    ? Icons.local_shipping_outlined
                    : Icons.local_shipping,
                color: selectedVehicle == null
                    ? AppTheme.textSecondary
                    : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selectedVehicle == null
                  ? const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Araç Seç",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Kullanılacak aracı seçin",
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedVehicle!.plate,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedVehicle!.type,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
            ),
            Icon(
              selectedVehicle == null
                  ? Icons.arrow_forward_ios
                  : Icons.check_circle,
              color: selectedVehicle == null
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
