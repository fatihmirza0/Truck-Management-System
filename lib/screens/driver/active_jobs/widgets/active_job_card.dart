// 📁 lib/screens/driver/active_jobs/widgets/active_job_card.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'info_row.dart';
import 'route_row.dart';
import '../../upload_document/pages/upload_document_page.dart';

class ActiveJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final String driverId;
  final String? vehiclePlate;
  final String? dispatchName;
  final String? dispatchPhone;

  const ActiveJobCard({
    super.key,
    required this.job,
    required this.jobId,
    required this.driverId,
    this.vehiclePlate,
    this.dispatchName,
    this.dispatchPhone,
  });

  static const Color border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final route = job['route'] as Map<String, dynamic>?;
    final cargo = job['cargo'] as Map<String, dynamic>?;

    final String referenceNo = (job['referenceNo'] ?? '-').toString();
    final String loadPort = (job['loadPort'] ?? route?['loadPort'] ?? '-').toString();
    final String unloadPort = (job['unloadPort'] ?? route?['unloadPort'] ?? '-').toString();
    final String cargoType = (job['cargoType'] ?? cargo?['type'] ?? '-').toString();
    final String cargoDesc = (job['cargoDescription'] ?? cargo?['description'] ?? '-').toString();
    final dynamic w = job['cargoWeightKg'] ?? cargo?['weightKg'];
    final String weightKg = (w == null) ? '-' : w.toString();

    final bool isCityRestricted = job['isCityRestricted'] == true;
    final Map<String, dynamic>? routeData = job['route'] as Map<String, dynamic>?;
    final Map<String, dynamic>? loadLatLng = routeData?['loadLatLng'] as Map<String, dynamic>?;
    final Map<String, dynamic>? unloadLatLng = routeData?['unloadLatLng'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isCityRestricted ? Colors.red.withOpacity(0.3) : border, width: isCityRestricted ? 2 : 1),
        boxShadow: isCityRestricted ? [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InfoRow(label: "Referans No", value: referenceNo),
              if (isCityRestricted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                      const SizedBox(width: 4),
                      Text(
                        "ŞEHİR İÇİ YASAK",
                        style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          InfoRow(
            label: "Yük",
            value: "$cargoType • ${weightKg == '-' ? '-' : '$weightKg kg'}",
          ),
          const SizedBox(height: 8),
          InfoRow(label: "Açıklama", value: cargoDesc),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          RouteRow(
            title: "Yükleme Noktası",
            value: loadPort,
          ),
          const SizedBox(height: 20),
          RouteRow(
            title: "Varış Noktası",
            value: unloadPort,
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          InfoRow(label: "Plaka", value: vehiclePlate ?? "-"),
          const SizedBox(height: 18),
          if (dispatchName != null) ...[
            InfoRow(label: "Dispatch", value: dispatchName ?? "-"),
            if (dispatchPhone != null) ...[
              const SizedBox(height: 8),
              InfoRow(label: "Telefon", value: dispatchPhone ?? "-"),
            ],
          ] else
            InfoRow(label: "Dispatch", value: "-"),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showNavigationPicker(context, loadPort, unloadPort, loadLatLng, unloadLatLng);
                    },
                    icon: const Icon(Icons.navigation_outlined, size: 20),
                    label: const Text("Navigasyon"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E3A5F),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isCityRestricted ? Colors.red.withOpacity(0.5) : Colors.blue.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UploadDocumentsPage(
                            jobId: jobId,
                            driverId: driverId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "İşi Tamamla",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNavigationPicker(BuildContext context, String load, String unload, Map? loadLL, Map? unloadLL) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Navigasyon Seçin",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tır rotası için Yandex tavsiye edilir.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.blue),
                title: const Text("Google Maps"),
                subtitle: const Text("Standart navigasyon"),
                onTap: () async {
                   Navigator.pop(context);
                   final origin = loadLL != null ? "${loadLL['lat']},${loadLL['lng']}" : Uri.encodeComponent(load);
                   final dest = unloadLL != null ? "${unloadLL['lat']},${unloadLL['lng']}" : Uri.encodeComponent(unload);
                   final url = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=driving');
                   if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.near_me_outlined, color: Colors.redAccent),
                title: const Text("Yandex Navigator"),
                subtitle: const Text("Tır rotası desteği (Tavsiye)"),
                onTap: () async {
                   Navigator.pop(context);
                   // Yandex deep link: yandexnavi://build_route_on_map?lat_from=...&lon_from=...&lat_to=...&lon_to=...
                   Uri url;
                   if (loadLL != null && unloadLL != null) {
                     url = Uri.parse('yandexnavi://build_route_on_map?lat_from=${loadLL['lat']}&lon_from=${loadLL['lng']}&lat_to=${unloadLL['lat']}&lon_to=${unloadLL['lng']}');
                   } else {
                     // Fallback to coordinates search if LatLng missing (less precise but works)
                     url = Uri.parse('yandexnavi://build_route_on_map?lat_to=${Uri.encodeComponent(unload)}');
                   }
                   
                   try {
                     if (await canLaunchUrl(url)) {
                       await launchUrl(url);
                     } else {
                       // Fallback to store if not installed
                       final storeUrl = Uri.parse('https://yandex.com.tr/navigasyon/');
                       await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
                     }
                   } catch (e) {
                      debugPrint("Yandex error: $e");
                   }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

