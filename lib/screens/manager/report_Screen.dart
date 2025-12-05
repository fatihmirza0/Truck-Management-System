import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '/utils/report_exporter.dart';
import '/utils/route_utils.dart';

/// ------------------------------------------------------------
/// HAFTA HESAPLAMA → Pazartesi başlangıçlı aynı haftada mı?
/// ------------------------------------------------------------
extension WeekStartExtension on DateTime {
  DateTime get weekStart {
    final dayOnly = DateTime(year, month, day);
    final diff = dayOnly.weekday - DateTime.monday; // Pazartesi = 1
    return dayOnly.subtract(Duration(days: diff));
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool loading = true;

  List<DocumentSnapshot> users = [];
  List<DocumentSnapshot> jobs = [];

  // 🔥 FAST LOOKUP INDEX
  Map<String, Map<String, dynamic>> driverIndex = {};
  Map<String, Map<String, dynamic>> dispatchIndex = {};

  // 🔥 KPI
  int todayJobs = 0;
  int weeklyJobs = 0;
  int monthlyJobs = 0;

  // 🔥 COUNTERS
  Map<String, int> driverJobCount = {};
  Map<String, double> driverKmCount = {};
  Map<String, int> dispatchJobCount = {};

  // 🔥 TOPS
  String topDriverId = "-";
  String topKmDriverId = "-";
  String topDispatchId = "-";
  double maxKm = 0;

  // 🔥 MONTHLY CHART DATA (12 AY)
  List<int> monthlyJobChart = List.filled(12, 0);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ------------------------------------------------------------
  // FIRESTORE LOAD + INDEX BUILD
  // ------------------------------------------------------------
  Future<void> loadData() async {
    final u = await FirebaseFirestore.instance.collection("users").get();
    final j = await FirebaseFirestore.instance.collection("jobs").get();

    users = u.docs;
    jobs = j.docs;

    // INDEX BUILD
    for (final doc in users) {
      final data = doc.data() as Map<String, dynamic>;
      final role = data["roleId"];

      if (role == "driver" && data["driverId"] != null) {
        driverIndex[data["driverId"]] = data;
      }

      if (role == "dispatch" && data["dispatchId"] != null) {
        dispatchIndex[data["dispatchId"]] = data;
      }
    }

    await _calculateStats();
    if (mounted) {
      setState(() => loading = false);
    }
  }

  // ------------------------------------------------------------
  // STATS CALCULATION
  // ------------------------------------------------------------
  Future<void> _calculateStats() async {
    final now = DateTime.now();
    final nowWeekStart = now.weekStart;

    for (final job in jobs) {
      final data = job.data() as Map<String, dynamic>;
      final createdAt = (data["createdAt"] as Timestamp).toDate();

      final String? driverId = data["assignedTo"];
      final String? dispatchId = data["assignedBy"];

      // KPI
      if (_isSameDay(createdAt, now)) todayJobs++;

      if (createdAt.weekStart == nowWeekStart) {
        weeklyJobs++;
      }

      if (createdAt.year == now.year && createdAt.month == now.month) {
        monthlyJobs++;
      }

      // MONTHLY CHART
      monthlyJobChart[createdAt.month - 1]++;

      // DRIVER COUNT
      if (driverId != null) {
        driverJobCount[driverId] = (driverJobCount[driverId] ?? 0) + 1;
      }

      // DISPATCH COUNT
      if (dispatchId != null) {
        dispatchJobCount[dispatchId] = (dispatchJobCount[dispatchId] ?? 0) + 1;
      }

      // -----------------------------------------------------
      // KM CALCULATION (CACHE + HAVERSINE BACKUP)
      // -----------------------------------------------------
      // -----------------------------------------------------
// KM CALCULATION
// -----------------------------------------------------
      double km = 0;

      if (data["distanceKm"] != null && data["distanceKm"] > 0) {
        km = (data["distanceKm"] as num).toDouble();
      } else {
        // portları geocode et
        final loc1 = await RouteUtils.geocode(data["loadPort"]);
        final loc2 = await RouteUtils.geocode(data["unloadPort"]);

        if (loc1 != null && loc2 != null) {

          // 🔥 Google KM
          km = await RouteUtils.getRouteKm(
            loc1["lat"]!, loc1["lng"]!,
            loc2["lat"]!, loc2["lng"]!,
          );

          // fallback düşükse haversine kullan
          if (km < 1) {
            km = RouteUtils.haversineKm(
              loc1["lat"]!, loc1["lng"]!,
              loc2["lat"]!, loc2["lng"]!,
            );
          }

          // Firestore'a cachele (bir daha API çağrısı açmaz)
          await FirebaseFirestore.instance.collection("jobs")
              .doc(job.id).update({"distanceKm": km});
        }
      }

      if (driverId != null) {
        driverKmCount[driverId] = (driverKmCount[driverId] ?? 0) + km;
      }

    }

    // TOP DRIVER
    if (driverJobCount.isNotEmpty) {
      final sorted = driverJobCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topDriverId = sorted.first.key;
    }

    // TOP KM DRIVER
    if (driverKmCount.isNotEmpty) {
      final sortedKm = driverKmCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topKmDriverId = sortedKm.first.key;
      maxKm = sortedKm.first.value;
    }

    // TOP DISPATCH
    if (dispatchJobCount.isNotEmpty) {
      final sortedD = dispatchJobCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topDispatchId = sortedD.first.key;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
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

    final isDesktop = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📦 Genel KPI",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      tooltip: "PDF dışa aktar",
                      onPressed: _exportPdf,
                    ),
                    IconButton(
                      icon: const Icon(Icons.table_chart, color: Colors.green),
                      tooltip: "Excel dışa aktar",
                      onPressed: _exportExcel,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            _kpiGrid(isDesktop),
            const SizedBox(height: 40),

            _title("📈 Aylık İş Dağılımı"),
            const SizedBox(height: 10),
            _monthlyChart(),

            const SizedBox(height: 40),
            _title("🚚 Şoför KM Performansı"),
            const SizedBox(height: 10),
            _driverKmChart(),

            const SizedBox(height: 40),
            _title("🧑‍💼 Dispatch Performansı"),
            const SizedBox(height: 10),
            dispatchPerformanceChart(),

            const SizedBox(height: 40),
            _title("👷 Şoför Tablosu"),
            const SizedBox(height: 10),
            _driverTable(),
          ],
        ),
      ),
    );
  }


  // ------------------------------------------------------------
  // KPI GRID
  // ------------------------------------------------------------
  Widget _kpiGrid(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 3 : 1,
      shrinkWrap: true,
      childAspectRatio: isDesktop ? 3 : 2.2,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _kpiCard("Bugünkü İşler", todayJobs.toString()),
        _kpiCard("Haftalık İşler", weeklyJobs.toString()),
        _kpiCard("Aylık İşler", monthlyJobs.toString()),
        _kpiCard("En Çok İş Yapan Şoför", _driverName(topDriverId)),
        _kpiCard("En Çok KM Yapan Şoför", "${maxKm.toStringAsFixed(1)} km"),
        _kpiCard("En Çok Atama Yapan Dispatch", _dispatchName(topDispatchId)),
      ],
    );
  }

  Widget _kpiCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(8),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  // ------------------------------------------------------------
  // 📈 MONTHLY CHART
  // ------------------------------------------------------------
  Widget _monthlyChart() {
    return Container(
      height: 260,
      padding: const EdgeInsets.all(12),
      decoration: _box(),
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const m = [
                    "O",
                    "Ş",
                    "M",
                    "N",
                    "M",
                    "H",
                    "T",
                    "A",
                    "E",
                    "E",
                    "K",
                    "A"
                  ];
                  if (v.toInt() < 0 || v.toInt() > 11) {
                    return const SizedBox();
                  }
                  return Text(m[v.toInt()]);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: List.generate(12, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthlyJobChart[i].toDouble(),
                  width: 18,
                  color: Colors.blueAccent,
                )
              ],
            );
          }),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // DRIVER KM CHART
  // ------------------------------------------------------------
  Widget _driverKmChart() {
    if (driverKmCount.isEmpty) {
      return const Text("KM verisi bulunamadı.");
    }

    final list = driverKmCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      height: list.length * 55,
      child: Column(
        children: List.generate(list.length, (i) {
          final id = list[i].key;
          final km = list[i].value;
          final name = _driverName(id);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                /// 🟩 Şoför adı
                SizedBox(
                  width: 160,
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),

                /// 🟩 Yatay KM bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (ctx, size) {
                          final maxKm = list.first.value == 0 ? 1 : list.first.value;
                          final ratio = km / maxKm;
                          final width = ratio * size.maxWidth * .90; // FULL değil!

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            height: 22,
                            width: width,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                /// 🔥 KM sayısı net şekilde
                Text(
                  "${km.toStringAsFixed(1)} km",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------
  // DISPATCH CHART
  // ------------------------------------------------------------
  Widget dispatchPerformanceChart() {
    final list = dispatchJobCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (list.isEmpty) return const Text("Henüz iş atayan dispatch yok.");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      height: list.length * 55,
      child: Column(
        children: List.generate(list.length, (i) {
          final id = list[i].key;
          final count = list[i].value;
          final name = _dispatchName(id);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                /// 🔹 Dispatch adı
                SizedBox(
                  width: 140,
                  child: Text(
                    name == "Bilinmiyor" ? id : name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),

                /// 🔹 Bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),

                      /// oransal bar genişliği
                      LayoutBuilder(
                        builder: (ctx, size) {
                          final maxCount = list.map((e) => e.value).reduce((a,b)=>a>b?a:b);

                          /// En çok iş yapan bile %90 genişlikte olsun
                          final ratio = count / maxCount;
                          final width = ratio * size.maxWidth * .90;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 22,
                            width: width,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                /// 🔥 sayı HER ZAMAN GÖRÜNÜR
                Text(
                  "$count",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------
  // DRIVER TABLE
  // ------------------------------------------------------------
  Widget _driverTable() {
    final rows = driverJobCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (rows.isEmpty) {
      return const Text("Şoför verisi bulunamadı.");
    }

    return Container(
      decoration: _box(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    "Şoför",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Plaka",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    "İş Sayısı",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    "Toplam KM",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          ...rows.map((e) {
            final driver = driverIndex[e.key];
            final km = driverKmCount[e.key] ?? 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(driver?["name"] ?? "Bilinmiyor")),
                  Expanded(child: Text(driver?["plateNumber"] ?? "-")),
                  Expanded(child: Text("${e.value} iş")),
                  Expanded(child: Text("${km.toStringAsFixed(1)} km")),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // EXPORT HANDLERS
  // ------------------------------------------------------------
  Future<void> _exportPdf() async {
    final drivers = driverJobCount.entries.map((e) {
      final d = driverIndex[e.key];
      return {
        "name": d?["name"] ?? "Bilinmiyor",
        "plate": d?["plateNumber"] ?? "-",
        "jobs": e.value,
        "km": (driverKmCount[e.key] ?? 0).toStringAsFixed(1),
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
      monthlyChart: monthlyJobChart,
      today: todayJobs,
      weekly: weeklyJobs,
      monthly: monthlyJobs,
      totalDrivers: driverIndex.length,
      totalDispatch: dispatchIndex.length,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📄 PDF oluşturuldu."),
        ),
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
        "km": (driverKmCount[e.key] ?? 0).toStringAsFixed(1),
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
        const SnackBar(
          content: Text("📊 Excel oluşturma tamamlandı!"),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // SMALL HELPERS
  // ------------------------------------------------------------
  String _driverName(String id) =>
      driverIndex[id]?["name"] ?? "Bilinmiyor";

  String _dispatchName(String id) =>
      dispatchIndex[id]?["name"] ?? "Bilinmiyor";

  BoxDecoration _box() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          blurRadius: 8,
          spreadRadius: 1,
          offset: const Offset(0, 2),
          color: Colors.black.withOpacity(0.08),
        ),
      ],
    );
  }

  Widget _title(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
