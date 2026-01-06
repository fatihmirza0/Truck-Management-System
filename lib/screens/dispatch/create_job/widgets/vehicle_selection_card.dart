// 📁 lib/pages/widgets/vehicle_selection_card.dart
import 'package:flutter/material.dart';

class VehicleSelectionCard extends StatelessWidget {
  final Map<String, dynamic>? selectedVehicle;
  final VoidCallback onTap;

  const VehicleSelectionCard({
    super.key,
    required this.selectedVehicle,
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
          color: selectedVehicle == null ? cardBg : accent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedVehicle == null ? border : accent,
            width: selectedVehicle == null ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selectedVehicle == null ? bg : accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                selectedVehicle == null ? Icons.local_shipping_outlined : Icons.local_shipping,
                color: selectedVehicle == null ? textSecondary : accent,
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
                      color: textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Kullanılacak aracı seçin",
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedVehicle!['plate'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selectedVehicle!['type'] ?? '-',
                    style: const TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selectedVehicle == null ? Icons.arrow_forward_ios : Icons.check_circle,
              color: selectedVehicle == null ? textSecondary : success,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}