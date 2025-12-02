import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompletedJobDetailsPage extends StatelessWidget {
  final Map<String, dynamic> job;

  const CompletedJobDetailsPage({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final createdAt = job['createdAt']?.toDate();
    final approvedAt = job['approvedAt']?.toDate();
    final completedAt = job['completedAt']?.toDate();

    String durationText = "-";

    if (createdAt != null && completedAt != null) {
      final diff = completedAt.difference(createdAt);
      durationText = "${diff.inHours} saat ${diff.inMinutes.remainder(60)} dk";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tamamlanan İş Detayı"),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// --------------------------------------------------------------
            /// YÜK BİLGİSİ BAŞLIK KARTI
            /// --------------------------------------------------------------
            _headerCard(job['cargoInfo'] ?? "-"),

            const SizedBox(height: 24),

            /// --------------------------------------------------------------
            /// YÜKLEME
            /// --------------------------------------------------------------
            _sectionTitle("Yükleme Limanı"),
            _infoBox(job['loadPort'] ?? "-"),

            const SizedBox(height: 24),

            /// --------------------------------------------------------------
            /// VARIŞ
            /// --------------------------------------------------------------
            _sectionTitle("Varış Limanı"),
            _infoBox(job['unloadPort'] ?? "-"),

            const SizedBox(height: 24),

            /// --------------------------------------------------------------
            /// DISPATCH
            /// --------------------------------------------------------------
            _sectionTitle("Dispatch"),
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('dispatchId', isEqualTo: job['assignedBy'])
                  .limit(1)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _infoBox("Yükleniyor...");
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _infoBox("Bulunamadı");
                }

                final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                final name = data['name'] ?? "Bilinmiyor";
                final phone = data['phone'] ?? "-";

                return Column(
                  children: [
                    _infoBox(name),
                    const SizedBox(height: 10),
                    _infoBox("Telefon: $phone"),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            /// --------------------------------------------------------------
            /// TARİHLER
            /// --------------------------------------------------------------
            _sectionTitle("İşlem Tarihleri"),
            _dateRow("Oluşturulma", createdAt),
            _dateRow("Onaylanma", approvedAt),
            _dateRow("Tamamlanma", completedAt),

            const SizedBox(height: 24),

            /// --------------------------------------------------------------
            /// TOPLAM SÜRE
            /// --------------------------------------------------------------
            _sectionTitle("Toplam İş Süresi"),
            _infoBox(durationText),
          ],
        ),
      ),
    );
  }

  /// -----------------------------------------------------------------
  /// PREMIUM TARZ BAŞLIK KARTI
  /// -----------------------------------------------------------------
  Widget _headerCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "📦 Yük Bilgisi",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// -----------------------------------------------------------------
  /// BÖLÜM BAŞLIĞI
  /// -----------------------------------------------------------------
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// -----------------------------------------------------------------
  /// PREMIUM BİLGİ KUTUSU — RENKSİZ
  /// -----------------------------------------------------------------
  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// -----------------------------------------------------------------
  /// TARİH SATIRI
  /// -----------------------------------------------------------------
  Widget _dateRow(String label, DateTime? date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              date != null
                  ? DateFormat('dd MMM yyyy - HH:mm').format(date)
                  : "-",
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
