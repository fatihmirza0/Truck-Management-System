// 📁 lib/pages/widgets/job_card.dart
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final String driverName;
  final String vehiclePlate;
  final VoidCallback onTap;

  const JobCard({
    super.key,
    required this.job,
    required this.jobId,
    required this.driverName,
    required this.vehiclePlate,
    required this.onTap,
  });

  static const Color primary = Color(0xFF1E3A5F);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    final status = job["status"];
    final statusColor = FirestoreService.getStatusColor(status);
    final statusText = FirestoreService.getStatusText(status);

    final route = job["route"] as Map<String, dynamic>? ?? {};
    final loadPort = route["loadPort"] ?? "-";
    final unloadPort = route["unloadPort"] ?? "-";

    final cargo = job["cargo"] as Map<String, dynamic>? ?? {};
    final cargoType = cargo["type"] ?? "-";
    final cargoWeight = cargo["weightKg"] != null
        ? "${cargo["weightKg"]} kg"
        : "-";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Ref No and Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job["referenceNo"] ?? "REF-XXX",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                          Text(
                            cargoType,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Driver Info
                _buildInfoRow(
                  Icons.person_outline,
                  "Şoför",
                  driverName,
                ),
                const SizedBox(height: 8),

                // Vehicle Info
                _buildInfoRow(
                  Icons.local_shipping_outlined,
                  "Araç",
                  vehiclePlate,
                ),
                const SizedBox(height: 8),

                // Route Info
                _buildInfoRow(
                  Icons.route_outlined,
                  "Güzergah",
                  "$loadPort → $unloadPort",
                ),
                const SizedBox(height: 8),

                // Cargo Weight
                _buildInfoRow(
                  Icons.scale_outlined,
                  "Ağırlık",
                  cargoWeight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textSecondary),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontSize: 13,
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: textTertiary,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}