import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final String Function(String?) userName;
  final String Function(String?) vehiclePlate;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const JobCard({
    super.key,
    required this.job,
    required this.jobId,
    required this.userName,
    required this.vehiclePlate,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = job['status'] ?? 'pending';
    final cargo = job['cargo'] as Map<String, dynamic>?;
    final route = job['route'] as Map<String, dynamic>?;

    return SlideInWidget(
      child: AnimatedCard(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Reference & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "REFERANS",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textTertiary,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          job['referenceNo'] ?? "-",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              const SizedBox(height: 14),

              // Route Visual
              _buildRouteVisual(route),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),

              // Info Grid
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.person_outline,
                      "Şoför",
                      userName(job['driverId']),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.local_shipping_outlined,
                      "Plaka",
                      vehiclePlate(job['vehicleId']),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.inventory_2_outlined,
                      "Yük",
                      cargo?['type'] ?? "-",
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.scale_outlined,
                      "Ağırlık",
                      "${cargo?['weightKg'] ?? 0} kg",
                    ),
                  ),
                ],
              ),

              // Action Buttons for Pending
              if (status == "pending") ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: onReject,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: const Center(
                            child: Text(
                              "Reddet",
                              style: TextStyle(
                                color: Color(0xFFE11D48),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ScaleButton(
                        onTap: onApprove,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFDCFCE7)),
                          ),
                          child: const Center(
                            child: Text(
                              "Onayla",
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case "pending":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = "Bekliyor";
        break;
      case "approved":
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF2563EB);
        label = "Onaylandı";
        break;
      case "rejected":
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = "Reddedildi";
        break;
      case "completed":
        bgColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF16A34A);
        label = "Tamamlandı";
        break;
      default:
        bgColor = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildRouteVisual(Map<String, dynamic>? route) {
    return Column(
      children: [
        _buildRoutePoint(
          Icons.location_on_rounded,
          AppTheme.primaryColor,
          route?['loadPort'] ?? "Yükleme Noktası",
          true,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            width: 1.5,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor,
                  const Color(0xFFCBD5E1),
                ],
              ),
            ),
          ),
        ),
        _buildRoutePoint(
          Icons.flag_rounded,
          const Color(0xFF64748B),
          route?['unloadPort'] ?? "Varış Noktası",
          false,
        ),
      ],
    );
  }

  Widget _buildRoutePoint(IconData icon, Color color, String text, bool isStart) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isStart ? FontWeight.w700 : FontWeight.w600,
              color: isStart ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Icon(icon, size: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
