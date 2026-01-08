// 📁 lib/screens/driver/active_jobs/widgets/route_row.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteRow extends StatelessWidget {
  final String title;
  final String value;

  const RouteRow({
    super.key,
    required this.title,
    required this.value,
  });

  static const Color primary = Color(0xFF1E3A5F);
  static const Color textDark = Color(0xFF0F172A);

  Future<void> _openMaps(String query) async {
    final q = query.trim();
    if (q.isEmpty || q == "-") return;
    final encoded = Uri.encodeComponent(q);
    final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$encoded");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final v = value.trim().isEmpty ? "-" : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: Color(0xFF475569),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textDark,
                ),
              ),
            ),
            IconButton(
              onPressed: v == "-" ? null : () => _openMaps(value),
              icon: const Icon(Icons.map_outlined, size: 20),
              color: primary,
              tooltip: "Haritada aç",
            ),
          ],
        ),
      ],
    );
  }
}


