// ------------------------------------------------------------
//  MODERN ENTERPRISE REPORT SCREEN
//  Pixel-Perfect Responsive Design + Year/Month Filter + YoY
// ------------------------------------------------------------
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/utils/report_exporter.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool loading = true;
  Map<String, String> vehiclePlateCache = {};

  List<DocumentSnapshot> users = [];
  List<DocumentSnapshot> jobs = [];

  Map<String, Map<String, dynamic>> driverIndex = {};
  Map<String, Map<String, dynamic>> dispatchIndex = {};

  // ================= FİLTRE =================
  int selectedYear = DateTime.now().year;
  int? selectedMonth;
  List<int> availableYears = [];

  // ================= KPI =================
  int todayJobs = 0;
  int weeklyJobs = 0;
  int monthlyJobs = 0;

  // ================= GEÇEN YIL KARŞILAŞTIRMA =================
  int prevYearJobs = 0;
  double jobChangePercent = 0;

  // ================= AGGREGATES =================
  Map<String, int> driverJobCount = {};
  Map<String, double> driverKm = {};
  Map<String, double> driverHours = {};
  Map<String, Set<String>> driverVehicles = {};
  Map<String, int> dispatchJobCount = {};

  List<int> monthlyChart = List.filled(12, 0);

  String topDriver = "-";
  String topKmDriver = "-";
  String topDispatch = "-";
  double topKm = 0;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;
  bool get isTablet =>
      MediaQuery.of(context).size.width > 600 &&
      MediaQuery.of(context).size.width <= 900;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicles = await FirebaseFirestore.instance
          .collection("vehicles")
          .where("isActive", isEqualTo: true)
          .get();

      vehiclePlateCache = {
        for (var v in vehicles.docs) v.id: v["plate"] ?? "-"
      };

      users = await FirestoreService.fetchAllUsers();
      jobs = await FirestoreService.fetchAllJobs();

      driverIndex.clear();
      dispatchIndex.clear();

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

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("Report load error → $e");
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _calculateStats() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    // Reset
    todayJobs = 0;
    weeklyJobs = 0;
    monthlyJobs = 0;
    prevYearJobs = 0;
    jobChangePercent = 0;

    driverJobCount.clear();
    driverKm.clear();
    driverHours.clear();
    driverVehicles.clear();
    dispatchJobCount.clear();

    for (int i = 0; i < 12; i++) {
      monthlyChart[i] = 0;
    }
    availableYears.clear();
    availableYears.add(selectedYear);

    for (final doc in jobs) {
      final j = doc.data() as Map<String, dynamic>;

      if (j["softDeleted"] == true) continue;
      if (j["status"] != "completed") continue;

      final ts = j["timestamps"]?["createdAt"] as Timestamp?;
      if (ts == null) continue;

      final created = ts.toDate();

      if (!availableYears.contains(created.year)) {
        availableYears.add(created.year);
      }

      final driverUid = j["driverId"];
      final dispatchUid = j["createdBy"];
      final vehicleId = j["vehicleId"];

      final matchesYear = created.year == selectedYear;
      final matchesMonth =
          selectedMonth == null || created.month == selectedMonth;

      if (created.year == selectedYear - 1 &&
          (selectedMonth == null || created.month == selectedMonth)) {
        prevYearJobs++;
      }

      if (!matchesYear || !matchesMonth) continue;

      if (_sameDay(created, now)) todayJobs++;
      if (created.isAfter(weekStart)) weeklyJobs++;
      monthlyJobs++;

      monthlyChart[created.month - 1]++;

      if (driverUid != null) {
        driverJobCount[driverUid] = (driverJobCount[driverUid] ?? 0) + 1;

        double km = (j["distanceKm"] ?? 0).toDouble();
        driverKm[driverUid] = (driverKm[driverUid] ?? 0) + km;

        double hours = (j["durationHours"] ?? 0).toDouble();
        driverHours[driverUid] = (driverHours[driverUid] ?? 0) + hours;

        if (vehicleId != null) {
          (driverVehicles[driverUid] ??= <String>{}).add(vehicleId);
        }
      }

      if (dispatchUid != null) {
        dispatchJobCount[dispatchUid] =
            (dispatchJobCount[dispatchUid] ?? 0) + 1;
      }
    }

    availableYears.sort((a, b) => b.compareTo(a));

    if (prevYearJobs > 0) {
      jobChangePercent = ((monthlyJobs - prevYearJobs) / prevYearJobs) * 100;
    }

    if (driverJobCount.isNotEmpty) {
      topDriver = driverJobCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    } else {
      topDriver = "-";
    }

    if (driverKm.isNotEmpty) {
      final topEntry =
          driverKm.entries.reduce((a, b) => a.value > b.value ? a : b);
      topKmDriver = topEntry.key;
      topKm = topEntry.value;
    }

    if (dispatchJobCount.isNotEmpty) {
      topDispatch = dispatchJobCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 32 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildKpiCards(),
              const SizedBox(height: 32),
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildMonthlyChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildDriverKmSection()),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDispatchSection()),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildDriverTable()),
                  ],
                ),
              ] else ...[
                _buildMonthlyChart(),
                const SizedBox(height: 24),
                _buildDriverKmSection(),
                const SizedBox(height: 24),
                _buildDispatchSection(),
                const SizedBox(height: 24),
                _buildDriverTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (isDesktop) {
      return _buildDesktopHeader();
    } else {
      return _buildMobileHeader();
    }
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.analytics_outlined,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Genel KPI Raporu",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Performans metriklerini ve istatistikleri görüntüleyin",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildYearDropdown(),
        const SizedBox(width: 12),
        _buildMonthDropdown(),
        const SizedBox(width: 16),
        _buildExportButton(
          icon: Icons.picture_as_pdf,
          label: "PDF",
          color: const Color(0xFFDC2626),
          onPressed: _exportPdf,
        ),
        const SizedBox(width: 12),
        _buildExportButton(
          icon: Icons.table_chart,
          label: "Excel",
          color: const Color(0xFF059669),
          onPressed: _exportExcel,
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.analytics_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Genel KPI Raporu",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Performans metrikleri",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF1E3A5F)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'pdf') _exportPdf();
                if (value == 'excel') _exportExcel();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf,
                          color: Color(0xFFDC2626), size: 20),
                      SizedBox(width: 12),
                      Text('PDF İndir'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'excel',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart,
                          color: Color(0xFF059669), size: 20),
                      SizedBox(width: 12),
                      Text('Excel İndir'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildYearDropdown()),
            const SizedBox(width: 12),
            Expanded(child: _buildMonthDropdown()),
          ],
        ),
      ],
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: availableYears.contains(selectedYear) ? selectedYear : null,
            hint: Text(selectedYear.toString()),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            items: availableYears.isEmpty
                ? [
                    DropdownMenuItem(
                      value: selectedYear,
                      child: Text(selectedYear.toString()),
                    )
                  ]
                : availableYears.map((year) {
                    return DropdownMenuItem(
                      value: year,
                      child: Text(
                        year.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                selectedYear = val;
                _load();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<int?>(
        value: selectedMonth,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, size: 20),
        isExpanded: !isDesktop,
        items: const [
          DropdownMenuItem(value: null, child: Text("Tüm Aylar")),
          DropdownMenuItem(value: 1, child: Text("Ocak")),
          DropdownMenuItem(value: 2, child: Text("Şubat")),
          DropdownMenuItem(value: 3, child: Text("Mart")),
          DropdownMenuItem(value: 4, child: Text("Nisan")),
          DropdownMenuItem(value: 5, child: Text("Mayıs")),
          DropdownMenuItem(value: 6, child: Text("Haziran")),
          DropdownMenuItem(value: 7, child: Text("Temmuz")),
          DropdownMenuItem(value: 8, child: Text("Ağustos")),
          DropdownMenuItem(value: 9, child: Text("Eylül")),
          DropdownMenuItem(value: 10, child: Text("Ekim")),
          DropdownMenuItem(value: 11, child: Text("Kasım")),
          DropdownMenuItem(value: 12, child: Text("Aralık")),
        ],
        onChanged: (val) {
          setState(() {
            selectedMonth = val;
            _load();
          });
        },
      ),
    );
  }

  Widget _buildExportButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ScaleButton(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCards() {
    int crossAxisCount;
    double childAspectRatio;
    double spacing;

    if (isDesktop) {
      crossAxisCount = 4;
      childAspectRatio = 1.6;
      spacing = 16;
    } else if (isTablet) {
      crossAxisCount = 3;
      childAspectRatio = 1.4;
      spacing = 12;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
      spacing = 12;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          children: [
            _buildKpiCard(
              icon: Icons.today_outlined,
              title: "Bugünkü İşler",
              value: todayJobs.toString(),
              color: const Color(0xFF3B82F6),
            ),
            _buildKpiCard(
              icon: Icons.calendar_view_week_outlined,
              title: "Haftalık İşler",
              value: weeklyJobs.toString(),
              color: const Color(0xFF8B5CF6),
            ),
            _buildKpiCard(
              icon: Icons.calendar_month_outlined,
              title: "Aylık İşler",
              value: monthlyJobs.toString(),
              color: const Color(0xFFEC4899),
            ),
            _buildKpiCard(
              icon: jobChangePercent >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              title: "Geçen Yıla Göre",
              value: "${jobChangePercent.toStringAsFixed(1)}%",
              color: jobChangePercent >= 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFDC2626),
            ),
            _buildKpiCard(
              icon: Icons.emoji_events_outlined,
              title: "En Çok İş Yapan",
              value: _driverName(topDriver),
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiCard(
              icon: Icons.route_outlined,
              title: "En Çok KM",
              value: "${topKm.toStringAsFixed(1)} km",
              color: const Color(0xFF10B981),
            ),
            _buildKpiCard(
              icon: Icons.support_agent_outlined,
              title: "Top Dispatch",
              value: _dispatchName(topDispatch),
              color: const Color(0xFF6366F1),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    double padding = isDesktop ? 16 : 12;
    double iconSize = isDesktop ? 20 : 18;
    double titleSize = isDesktop ? 12 : 10;
    double valueSize = isDesktop ? 20 : 16;

    return AnimatedCard(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: iconSize, color: color),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: valueSize,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyChart() {
    return _buildSection(
      title: "Aylık İş Dağılımı",
      icon: Icons.bar_chart_outlined,
      child: Container(
        height: isDesktop ? 300 : 250,
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: _buildBoxDecoration(),
        child: BarChart(
          BarChartData(
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: const Color(0xFFE2E8F0),
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const months = [
                      "Oca",
                      "Şub",
                      "Mar",
                      "Nis",
                      "May",
                      "Haz",
                      "Tem",
                      "Ağu",
                      "Eyl",
                      "Eki",
                      "Kas",
                      "Ara"
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        months[value.toInt()],
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 10,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 10,
                        color: const Color(0xFF64748B),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barGroups: List.generate(12, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: monthlyChart[i].toDouble(),
                    width: isDesktop ? 24 : 16,
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverKmSection() {
    if (driverKm.isEmpty) {
      return _buildSection(
        title: "Şoför KM Performansı",
        icon: Icons.route_outlined,
        child: _buildEmptyState("KM verisi bulunmuyor"),
      );
    }

    final sorted = driverKm.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sorted.take(isDesktop ? 5 : 3).toList();

    return _buildSection(
      title: "Şoför KM Performansı",
      icon: Icons.route_outlined,
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: _buildBoxDecoration(),
        child: Column(
          children: topItems.map((e) {
            final name = _driverName(e.key);
            final percentage = e.value / sorted.first.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${e.value.toStringAsFixed(1)} km",
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      color: const Color(0xFF059669),
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDispatchSection() {
    if (dispatchJobCount.isEmpty) {
      return _buildSection(
        title: "Dispatch Performansı",
        icon: Icons.support_agent_outlined,
        child: _buildEmptyState("Dispatch verisi bulunmuyor"),
      );
    }

    final sorted = dispatchJobCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topItems = sorted.take(isDesktop ? 5 : 3).toList();

    return _buildSection(
      title: "Dispatch Performansı",
      icon: Icons.support_agent_outlined,
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        decoration: _buildBoxDecoration(),
        child: Column(
          children: topItems.map((e) {
            final name = _dispatchName(e.key);
            final percentage = e.value / sorted.first.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "${e.value} iş",
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 8,
                      color: const Color(0xFFF59E0B),
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDriverTable() {
    final driverData = <String, Map<String, dynamic>>{};
    for (final driverId in driverJobCount.keys) {
      final jobs = driverJobCount[driverId] ?? 0;
      final km = driverKm[driverId] ?? 0;
      final hours = driverHours[driverId] ?? 0;
      final avgKm = jobs > 0 ? km / jobs : 0;
      final avgHours = jobs > 0 ? hours / jobs : 0;

      String plate = "-";
      final vehicleSet = driverVehicles[driverId];
      if (vehicleSet != null && vehicleSet.isNotEmpty) {
        final firstVehicleId = vehicleSet.first;
        plate = vehiclePlateCache[firstVehicleId] ?? "-";
      }

      driverData[driverId] = {
        'name': _driverName(driverId),
        'plate': plate,
        'jobs': jobs,
        'km': km,
        'avgKm': avgKm,
        'avgHours': avgHours,
      };
    }

    final sortedDrivers = driverData.entries.toList()
      ..sort((a, b) => b.value['jobs'].compareTo(a.value['jobs']));

    if (sortedDrivers.isEmpty) {
      return _buildSection(
        title: "Şoför Detay Tablosu",
        icon: Icons.table_chart_outlined,
        child: _buildEmptyState("Şoför verisi bulunmuyor"),
      );
    }

    return _buildSection(
      title: "Şoför Detay Tablosu",
      icon: Icons.table_chart_outlined,
      child: Container(
        decoration: _buildBoxDecoration(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              _buildDataColumn("Şoför", Icons.person_outline),
              _buildDataColumn("Plaka", Icons.car_rental_outlined),
              _buildDataColumn("İş", Icons.work_outline),
              _buildDataColumn("Toplam KM", Icons.route_outlined),
              _buildDataColumn("Ort. KM/İş", Icons.analytics_outlined),
              _buildDataColumn("Ort. Süre (saat)", Icons.timer_outlined),
            ],
            rows: sortedDrivers.map((entry) {
              final data = entry.value;
              return DataRow(
                cells: [
                  _buildDataTableCell(data['name']),
                  _buildDataTableCell(data['plate']),
                  _buildDataTableCell(data['jobs'].toString()),
                  _buildDataTableCell("${data['km'].toStringAsFixed(1)} km"),
                  _buildDataTableCell("${data['avgKm'].toStringAsFixed(1)} km"),
                  _buildDataTableCell(
                      "${data['avgHours'].toStringAsFixed(1)} saat"),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(String label, IconData icon) {
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  DataCell _buildDataTableCell(String text) {
    return DataCell(
      Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF1E3A5F)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 48 : 32),
      decoration: _buildBoxDecoration(),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              size: isDesktop ? 48 : 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _buildBoxDecoration() {
    return BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: AppTheme.softShadow,
    );
  }

  String _driverName(String uid) => driverIndex[uid]?["name"] ?? "Bilinmiyor";
  String _dispatchName(String uid) =>
      dispatchIndex[uid]?["name"] ?? "Bilinmiyor";
  Future<void> _exportPdf() async {
    final drivers = driverJobCount.entries.map((e) {
      final driverId = e.key;
      final jobs = e.value;
      final km = driverKm[driverId] ?? 0;
      final hours = driverHours[driverId] ?? 0;
      final avgKm = jobs > 0 ? km / jobs : 0;
      final avgHours = jobs > 0 ? hours / jobs : 0;
      String plate = "-";
      final vehicleSet = driverVehicles[driverId];
      if (vehicleSet != null && vehicleSet.isNotEmpty) {
        final firstVehicleId = vehicleSet.first;
        plate = vehiclePlateCache[firstVehicleId] ?? "-";
      }

      return {
        "name": _driverName(driverId),
        "plate": plate,
        "jobs": jobs,
        "km": km.toStringAsFixed(1),
        "avgKm": avgKm.toStringAsFixed(1),
        "avgHours": avgHours.toStringAsFixed(1),
      };
    }).toList();

    final dispatchers = dispatchJobCount.entries.map((e) {
      return {
        "name": _dispatchName(e.key),
        "jobs": e.value,
      };
    }).toList();

    await ReportExporter.exportPdf(
      year: selectedYear,
      month: selectedMonth,
      drivers: drivers,
      dispatchers: dispatchers,
      monthlyChart: monthlyChart,
      today: todayJobs,
      weekly: weeklyJobs,
      monthly: monthlyJobs,
      prevYearJobs: prevYearJobs,
      jobChangePercent: jobChangePercent,
      totalDrivers: driverIndex.length,
      totalDispatch: dispatchIndex.length,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("PDF başarıyla oluşturuldu"),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _exportExcel() async {
    final drivers = driverJobCount.entries.map((e) {
      final driverId = e.key;
      final jobs = e.value;
      final km = driverKm[driverId] ?? 0;
      final hours = driverHours[driverId] ?? 0;
      final avgKm = jobs > 0 ? km / jobs : 0;
      final avgHours = jobs > 0 ? hours / jobs : 0;
      String plate = "-";
      final vehicleSet = driverVehicles[driverId];
      if (vehicleSet != null && vehicleSet.isNotEmpty) {
        final firstVehicleId = vehicleSet.first;
        plate = vehiclePlateCache[firstVehicleId] ?? "-";
      }

      return {
        "name": _driverName(driverId),
        "plate": plate,
        "jobs": jobs,
        "km": km.toStringAsFixed(1),
        "avgKm": avgKm.toStringAsFixed(1),
        "avgHours": avgHours.toStringAsFixed(1),
      };
    }).toList();

    final dispatchers = dispatchJobCount.entries.map((e) {
      return {
        "name": _dispatchName(e.key),
        "jobs": e.value,
      };
    }).toList();

    await ReportExporter.exportExcel(
      year: selectedYear,
      month: selectedMonth,
      drivers: drivers,
      dispatchers: dispatchers,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("Excel başarıyla oluşturuldu"),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}
