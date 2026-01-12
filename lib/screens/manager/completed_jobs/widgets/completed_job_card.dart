import 'package:flutter/material.dart';
import '../../../../widgets/animated/animated_widgets.dart';

class CompletedJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String driverName;
  final String dateStr;
  final VoidCallback onTap;
  final int index; // For staggered animation

  static const Color accent = Color(0xFF1E3A5F);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  const CompletedJobCard({
    super.key,
    required this.job,
    required this.driverName,
    required this.dateStr,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final route = job["route"] as Map<String, dynamic>?;

    return SlideInWidget(
      delay: Duration(milliseconds: 50 * index),
      child: AnimatedCard(
        onTap: onTap,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        hoverElevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              // Premium Left Accent Bar
              Positioned(
                left: -20,
                top: 0,
                bottom: 0,
                width: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // REF NO & STATUS
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (job["referenceNo"] ?? "-").toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "TAMAMLANDI",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // DATE BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "TARİH",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: textMuted,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // INFO ROWS
                  _infoRow(
                    Icons.person_outline,
                    "ŞOFÖR",
                    driverName,
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.route_outlined,
                    "GÜZERGAH",
                    "${route?["loadPort"] ?? "-"} → ${route?["unloadPort"] ?? "-"}",
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // ACTION HINT
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(Icons.description_outlined,
                            size: 14, color: accent),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "İş Detayları",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "İNCELE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded,
                          color: accent, size: 16),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: textDark,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
