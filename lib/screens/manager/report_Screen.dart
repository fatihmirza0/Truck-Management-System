// ------------------------------------------------------------
//  REPORT SCREEN – FULLY REFACTORED (UID BASED ARCHITECTURE)
// ------------------------------------------------------------
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/utils/report_exporter.dart';


class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool loading = true;

  List<DocumentSnapshot> users = [];
  List<DocumentSnapshot> jobs = [];

  /// UID tabanlı indexler
  Map<String, Map<String, dynamic>> driverIndex = {};
  Map<String, Map<String, dynamic>> dispatchIndex = {};

  /// Sayısal istatistikler
  int todayJobs = 0;
  int weeklyJobs = 0;
  int monthlyJobs = 0;

  Map<String, int> driverJobCount = {};
  Map<String, double> driverKm = {};
  Map<String, int> dispatchJobCount = {};

  List<int> monthlyChart = List.filled(12, 0);

  String topDriver = "-";
  String topKmDriver = "-";
  String topDispatch = "-";
  double topKm = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ------------------------------------------------------------
  // MAIN LOADER
  // ------------------------------------------------------------
  Future<void> _load() async {
    try {
      final userSnap =
      await FirebaseFirestore.instance.collection("users").get();
      final jobSnap =
      await FirebaseFirestore.instance.collection("jobs").get();

      users = userSnap.docs;
      jobs = jobSnap.docs;

      /// UID → kullanıcı bilgisi indexi
      for (final doc in users) {
        final d = doc.data() as Map<String, dynamic>;
        final uid = doc.id;

        if (d["role"] == "driver") {
          driverIndex[uid] = d;
        }
        if (d["role"] == "dispatch") {
          dispatchIndex[uid] = d;
        }
      }

      await _calculateStats();

      if (mounted) setState(() => loading = false);
    } catch (e) {
      print("Report load error → $e");
    }
  }

  // ------------------------------------------------------------
  // CALCULATE STATS
  // ------------------------------------------------------------
  Future<void> _calculateStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    for (final doc in jobs) {
      final j = doc.data() as Map<String, dynamic>;

      final ts = j["createdAt"] as Timestamp?;
      if (ts == null) continue;

      final created = ts.toDate();
      final driverUid = j["assignedToUid"];
      final dispatchUid = j["assignedByUid"];

      /// Tarihsel istatistikler
      if (_sameDay(created, now)) todayJobs++;
      if (created.isAfter(weekStart)) weeklyJobs++;
      if (created.year == now.year && created.month == now.month) {
        monthlyJobs++;
      }

      monthlyChart[created.month - 1]++;

      /// ŞOFÖR ATAMA SAYISI
      if (driverUid != null) {
        driverJobCount[driverUid] = (driverJobCount[driverUid] ?? 0) + 1;
      }

      /// DISPATCH ATAMA SAYISI
      if (dispatchUid != null) {
        dispatchJobCount[dispatchUid] =
            (dispatchJobCount[dispatchUid] ?? 0) + 1;
      }

      /// KM hesaplama
      double km = (j["distanceKm"] ?? 0).toDouble();

      if (driverUid != null) {
        driverKm[driverUid] = (driverKm[driverUid] ?? 0) + km;
      }
    }

    /// EN İYİLERİ BUL
    if (driverJobCount.isNotEmpty) {
      topDriver = driverJobCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    if (driverKm.isNotEmpty) {
      final max = driverKm.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      topKmDriver = max.key;
      topKm = max.value;
    }

    if (dispatchJobCount.isNotEmpty) {
      topDispatch = dispatchJobCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 20),
            _kpiCards(),
            const SizedBox(height: 40),
            _section("📆 Aylık İş Dağılımı", _monthlyChartWidget()),
            const SizedBox(height: 40),
            _section("🚚 Şoför KM Performansı", _driverKmWidget()),
            const SizedBox(height: 40),
            _section("🧑‍💼 Dispatch Performansı", _dispatchWidget()),
            const SizedBox(height: 40),
            _section("👷 Şoför Tablosu", _driverTableWidget()),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------
  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "📊 Genel KPI Raporu",
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              onPressed: _exportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.table_chart, color: Colors.green),
              onPressed: _exportExcel,
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // KPI CARDS
  // ------------------------------------------------------------
  Widget _kpiCards() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3,
      children: [
        _kpi("Bugünkü İşler", todayJobs.toString()),
        _kpi("Haftalık İşler", weeklyJobs.toString()),
        _kpi("Aylık İşler", monthlyJobs.toString()),
        _kpi("En Çok İş Yapan Şoför", _driverName(topDriver)),
        _kpi("En Çok KM Yapan Şoför", "${topKm.toStringAsFixed(1)} km"),
        _kpi("En Çok Atama Yapan Dispatch", _dispatchName(topDispatch)),
      ],
    );
  }

  Widget _kpi(String title, String value) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(20),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // MONTHLY BAR CHART
  // ------------------------------------------------------------
  Widget _monthlyChartWidget() {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                const months = [
                  "Oca", "Şub", "Mar", "Nis", "May", "Haz",
                  "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"
                ];
                return Text(months[v.toInt()]);
              }),
            ),
            leftTitles:
            AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(12, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: monthlyChart[i].toDouble(),
                width: 18,
                color: Colors.blueAccent,
              )
            ]);
          }),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DRIVER KM CHART
  // ------------------------------------------------------------
  Widget _driverKmWidget() {
    if (driverKm.isEmpty) {
      return const Text("KM verisi bulunamadı.");
    }

    final sorted = driverKm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        children: sorted.map((e) {
          final name = _driverName(e.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 150, child: Text(name)),
                Expanded(
                  child: LinearProgressIndicator(
                    value: e.value / sorted.first.value,
                    color: Colors.green,
                    backgroundColor: Colors.green.withOpacity(.2),
                  ),
                ),
                const SizedBox(width: 10),
                Text("${e.value.toStringAsFixed(1)} km"),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------
  // DISPATCH PERFORMANCE
  // ------------------------------------------------------------
  Widget _dispatchWidget() {
    if (dispatchJobCount.isEmpty) {
      return const Text("Dispatch verisi yok.");
    }

    final sorted = dispatchJobCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        children: sorted.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 150, child: Text(_dispatchName(e.key))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: e.value / sorted.first.value,
                    color: Colors.orange,
                    backgroundColor: Colors.orange.withOpacity(.2),
                  ),
                ),
                const SizedBox(width: 10),
                Text("${e.value} iş"),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------------------------------------------------
  // DRIVER TABLE
  // ------------------------------------------------------------
  Widget _driverTableWidget() {
    if (driverJobCount.isEmpty) return const Text("Şoför verisi yok.");

    final sorted = driverJobCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: _box(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(.15),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(child: Text("Şoför", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("Plaka", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("İş", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("KM", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          ...sorted.map((e) {
            final uid = e.key;
            final d = driverIndex[uid];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black12)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(d?["name"] ?? "-")),
                  Expanded(child: Text(d?["plateNumber"] ?? "-")),
                  Expanded(child: Text("${e.value}")),
                  Expanded(child: Text("${(driverKm[uid] ?? 0).toStringAsFixed(1)} km")),
                ],
              ),
            );
          })
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------
  String _driverName(String uid) =>
      driverIndex[uid]?["name"] ?? "Bilinmiyor";

  String _dispatchName(String uid) =>
      dispatchIndex[uid]?["name"] ?? "Bilinmiyor";

  BoxDecoration _box() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.08),
        blurRadius: 8,
        offset: const Offset(0, 3),
      )
    ],
  );

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
  Future<void> _exportPdf() async {
    final drivers = driverJobCount.entries.map((e) {
      final d = driverIndex[e.key];
      return {
        "name": d?["name"] ?? "Bilinmiyor",
        "plate": d?["plateNumber"] ?? "-",
        "jobs": e.value,
        "km": (driverKm[e.key] ?? 0).toStringAsFixed(1),
      };
    }).toList();

    final dispatchers = dispatchJobCount.entries.map((e) {
      final d = dispatchIndex[e.key];
      return {
        "name": d?["name"] ?? "Bilinmiyor",
        "jobs": e.value,
      };
    }).toList();

    await ReportExporter.exportPdf(
      drivers: drivers,
      dispatchers: dispatchers,
      monthlyChart: monthlyChart,
      today: todayJobs,
      weekly: weeklyJobs,
      monthly: monthlyJobs,
      totalDrivers: driverIndex.length,
      totalDispatch: dispatchIndex.length,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📄 PDF oluşturuldu.")),
      );
    }
  }

  Future<void> _exportExcel() async {
    final drivers = driverJobCount.entries.map((e) {
      final d = driverIndex[e.key];
      return {
        "name": d?["name"] ?? "Bilinmiyor",
        "plate": d?["plateNumber"] ?? "-",
        "jobs": e.value,
        "km": (driverKm[e.key] ?? 0).toStringAsFixed(1),
      };
    }).toList();

    final dispatchers = dispatchJobCount.entries.map((e) {
      final d = dispatchIndex[e.key];
      return {
        "name": d?["name"] ?? "Bilinmiyor",
        "jobs": e.value,
      };
    }).toList();

    await ReportExporter.exportExcel(
      drivers: drivers,
      dispatchers: dispatchers,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📊 Excel oluşturuldu.")),
      );
    }
  }
}

