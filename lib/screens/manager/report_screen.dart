// ------------------------------------------------------------
//  REVOLUTIONARY MODERN ENTERPRISE REPORT SYSTEM
//  Comprehensive Analytics + Advanced Visuals + Smart Filtering
// ------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/utils/report_exporter.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool loading = true;
  
  // Data Lists
  List<DocumentSnapshot> allJobs = [];
  List<DocumentSnapshot> filteredJobs = [];
  List<DocumentSnapshot> allUsers = [];
  Map<String, String> vehiclePlateCache = {};

  // Filtering
  DateTimeRange? selectedDateRange;
  String? selectedDriverId;
  String? selectedCargoType;

  // KPI Metrics
  int totalJobsCount = 0;
  double totalDistanceKm = 0;
  double totalWeightKg = 0;
  double avgCompletionTimeHours = 0;

  // Analytics
  Map<String, int> cargoTypeDistribution = {};
  Map<String, int> portActivity = {};
  Map<String, int> monthlyDistribution = {};
  List<Map<String, dynamic>> driverPerformance = [];
  
  // UI Helpers
  bool get isDesktop => MediaQuery.of(context).size.width > 1100;
  bool get isTablet => MediaQuery.of(context).size.width > 700 && MediaQuery.of(context).size.width <= 1100;

  @override
  void initState() {
    super.initState();
    _setInitialDateRange();
    _loadData();
  }

  void _setInitialDateRange() {
    final now = DateTime.now();
    // Default to last 30 days
    selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    try {
      final companyId = await FirestoreService.getCompanyId();
      
      // Fetch data in parallel
      final results = await Future.wait([
        FirestoreService.fetchAllJobs(),
        FirestoreService.fetchAllUsers(),
        FirebaseFirestore.instance
            .collection("vehicles")
            .where("companyId", isEqualTo: companyId)
            .where("isActive", isEqualTo: true)
            .get(),
      ]);

      allJobs = results[0] as List<DocumentSnapshot>;
      allUsers = results[1] as List<DocumentSnapshot>;
      final vehicleDocs = (results[2] as QuerySnapshot).docs;

      vehiclePlateCache = {
        for (var v in vehicleDocs) v.id: v["plate"] ?? "-"
      };

      _applyFiltersAndCalculate();
    } catch (e) {
      debugPrint("Report load error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _applyFiltersAndCalculate() {
    filteredJobs = allJobs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Basic Filters
      if (data["softDeleted"] == true) return false;
      if (data["status"] != "completed") return false;

      // Date Range Filter
      final ts = data["timestamps"]?["completedAt"] ?? data["timestamps"]?["createdAt"];
      if (ts == null) return false;
      final date = (ts as Timestamp).toDate();
      
      if (selectedDateRange != null) {
        if (date.isBefore(selectedDateRange!.start) || 
            date.isAfter(selectedDateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Driver Filter
      if (selectedDriverId != null && data["driverId"] != selectedDriverId) return false;

      // Cargo Type Filter
      if (selectedCargoType != null && data["cargoType"] != selectedCargoType) return false;

      return true;
    }).toList();

    _calculateAllStats();
  }

  void _calculateAllStats() {
    // Reset metrics
    totalJobsCount = filteredJobs.length;
    totalDistanceKm = 0;
    totalWeightKg = 0;
    double totalHours = 0;
    
    cargoTypeDistribution.clear();
    portActivity.clear();
    monthlyDistribution.clear();
    Map<String, Map<String, dynamic>> driverStats = {};

    for (var doc in filteredJobs) {
      final d = doc.data() as Map<String, dynamic>;
      
      // Summations
      totalDistanceKm += (d["distanceKm"] ?? 0).toDouble();
      totalWeightKg += (d["cargoWeightKg"] ?? 0).toDouble();

      // Completion Time (Hours)
      final start = d["timestamps"]?["createdAt"] as Timestamp?;
      final end = d["timestamps"]?["completedAt"] as Timestamp?;
      if (start != null && end != null) {
        totalHours += end.toDate().difference(start.toDate()).inMinutes / 60;
      }

      // Cargo Type Dist
      final cType = d["cargoType"] ?? "Diğer";
      cargoTypeDistribution[cType] = (cargoTypeDistribution[cType] ?? 0) + 1;

      // Port Activity
      final port = d["loadPort"] ?? "Bilinmiyor";
      portActivity[port] = (portActivity[port] ?? 0) + 1;
      final uPort = d["unloadPort"] ?? "Bilinmiyor";
      portActivity[uPort] = (portActivity[uPort] ?? 0) + 1;

      // Monthly Dist
      final date = (d["timestamps"]?["createdAt"] as Timestamp).toDate();
      final monthKey = DateFormat('MMMM', 'tr').format(date);
      monthlyDistribution[monthKey] = (monthlyDistribution[monthKey] ?? 0) + 1;

      // Driver Performance
      final dId = d["driverId"];
      if (dId != null) {
        if (!driverStats.containsKey(dId)) {
          driverStats[dId] = {
            "jobs": 0,
            "km": 0.0,
            "weight": 0.0,
            "name": _getDriverName(dId),
          };
        }
        driverStats[dId]!["jobs"]++;
        driverStats[dId]!["km"] += (d["distanceKm"] ?? 0).toDouble();
        driverStats[dId]!["weight"] += (d["cargoWeightKg"] ?? 0).toDouble();
      }
    }

    avgCompletionTimeHours = totalJobsCount > 0 ? (totalHours / totalJobsCount) : 0;
    
    // Sort and convert driver stats
    driverPerformance = driverStats.values.toList();
    driverPerformance.sort((a, b) => (b["jobs"] as int).compareTo(a["jobs"] as int));
  }

  String _getDriverName(String id) {
    try {
      final user = allUsers.firstWhere((u) => u.id == id);
      return (user.data() as Map<String, dynamic>)["name"] ?? "Bilinmiyor";
    } catch (_) {
      return "Bilinmiyor";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKpiSection(),
                    const SizedBox(height: 32),
                    if (isDesktop) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildTrendChart()),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildCargoPie()),
                        ],
                      ),
                    ] else ...[
                      _buildTrendChart(),
                      const SizedBox(height: 24),
                      _buildCargoPie(),
                    ],
                    const SizedBox(height: 32),
                    if (isDesktop) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildPortActivityChart()),
                          const SizedBox(width: 24),
                          Expanded(flex: 3, child: _buildDriverPerformanceTable()),
                        ],
                      ),
                    ] else ...[
                      _buildPortActivityChart(),
                      const SizedBox(height: 24),
                      _buildDriverPerformanceTable(),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCustomHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 20,
        vertical: 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          ),
        ],
      ),
      child: isDesktop ? _buildDesktopHeaderContent() : _buildMobileHeaderContent(),
    );
  }

  Widget _buildDesktopHeaderContent() {
    return Row(
      children: [
        _buildHeaderTitle(),
        const Spacer(),
        _buildFilterChips(),
        const SizedBox(width: 24),
        _buildDateRangeButton(),
        const SizedBox(width: 16),
        _buildExportButtons(),
      ],
    );
  }

  Widget _buildMobileHeaderContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderTitle(),
            _buildExportButtons(isMini: true),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildDateRangeButton()),
            const SizedBox(width: 12),
            _buildMobileFilterAnchor(),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderTitle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryColor.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Operasyonel Analiz",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Verilerin gücüyle işletmenizi yönetin",
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildDropdownFilter(
          label: "Sürücü",
          value: selectedDriverId,
          items: [
            const DropdownMenuItem(value: null, child: Text("Tüm Sürücüler")),
            ...allUsers
                .where((u) => (u.data() as Map)["role"] == "driver")
                .map((u) => DropdownMenuItem(
                      value: u.id,
                      child: Text((u.data() as Map)["name"] ?? "Bilinmiyor"),
                    )),
          ],
          onChanged: (val) {
            setState(() {
              selectedDriverId = val;
              _applyFiltersAndCalculate();
            });
          },
        ),
        const SizedBox(width: 12),
        _buildDropdownFilter(
          label: "Yük Tipi",
          value: selectedCargoType,
          items: [
            const DropdownMenuItem(value: null, child: Text("Tüm Yükler")),
            ...cargoTypeDistribution.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))),
          ],
          onChanged: (val) {
            setState(() {
              selectedCargoType = val;
              _applyFiltersAndCalculate();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        underline: const SizedBox(),
        dropdownColor: Colors.white,
        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        hint: Text(label),
      ),
    );
  }

  Widget _buildDateRangeButton() {
    final startStr = DateFormat('d MMM', 'tr').format(selectedDateRange!.start);
    final endStr = DateFormat('d MMM yyyy', 'tr').format(selectedDateRange!.end);

    return ScaleButton(
      onTap: () async {
        final res = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2023),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          initialDateRange: selectedDateRange,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppTheme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
        );
        if (res != null) {
          setState(() {
            selectedDateRange = res;
            _applyFiltersAndCalculate();
          });
        }
      },
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(
              "$startStr - $endStr",
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilterAnchor() {
    return ScaleButton(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Filtrele", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildDropdownFilter(
                        label: "Sürücü Seç",
                        value: selectedDriverId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text("Tüm Sürücüler")),
                          ...allUsers
                              .where((u) => (u.data() as Map)["role"] == "driver")
                              .map((u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text((u.data() as Map)["name"] ?? "Bilinmiyor"),
                                  )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedDriverId = val;
                            _applyFiltersAndCalculate();
                          });
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      // Add more filters if needed
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Uygula", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Icon(Icons.tune_rounded, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildExportButtons({bool isMini = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconButton(
          icon: Icons.picture_as_pdf_outlined,
          color: const Color(0xFFE11D48),
          onTap: _exportPdf,
          mini: isMini,
        ),
        const SizedBox(width: 12),
        _buildIconButton(
          icon: Icons.table_chart_outlined,
          color: const Color(0xFF059669),
          onTap: _exportExcel,
          mini: isMini,
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool mini = false,
  }) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(mini ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: color, size: mini ? 20 : 24),
      ),
    );
  }

  Widget _buildKpiSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = isDesktop ? 4 : (isTablet ? 2 : 2);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: isDesktop ? 2.5 : 1.6,
          children: [
            _buildKpiCard(
              title: "Tamamlanan İşler",
              value: totalJobsCount.toString(),
              subtitle: "Operasyon Hacmi",
              icon: Icons.task_alt_rounded,
              color: const Color(0xFF6366F1),
            ),
            _buildKpiCard(
              title: "Toplam Mesafe",
              value: "${totalDistanceKm.toStringAsFixed(0)} KM",
              subtitle: "Kat Edilen Yol",
              icon: Icons.route_rounded,
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiCard(
              title: "Toplam Yük",
              value: "${(totalWeightKg / 1000).toStringAsFixed(1)} Ton",
              subtitle: "Taşınan Madde",
              icon: Icons.fitness_center_rounded,
              color: const Color(0xFFEC4899),
            ),
            _buildKpiCard(
              title: "Tamamlama Süresi",
              value: "${avgCompletionTimeHours.toStringAsFixed(1)} Sa",
              subtitle: "Ortalama Verim",
              icon: Icons.timer_rounded,
              color: const Color(0xFF10B981),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart() {
    return _buildSectionContainer(
      title: "Haftalık İş Trendi",
      subtitle: "Zaman bazlı performans analizi",
      icon: Icons.auto_graph_rounded,
      child: SizedBox(
        height: 300,
        child: LineChart(_getTrendData()),
      ),
    );
  }

  LineChartData _getTrendData() {
    final Map<int, int> dayStats = {};
    for (var doc in filteredJobs) {
      final date = (doc.data() as Map)["timestamps"]["createdAt"] as Timestamp;
      final weekday = date.toDate().weekday;
      dayStats[weekday] = (dayStats[weekday] ?? 0) + 1;
    }

    List<FlSpot> spots = [];
    for (int i = 1; i <= 7; i++) {
      spots.add(FlSpot(i.toDouble(), (dayStats[i] ?? 0).toDouble()));
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
              if (value < 1 || value > 7) return const SizedBox();
              return Text(days[value.toInt() - 1], style: TextStyle(color: Colors.grey[400], fontSize: 10));
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryColor,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor.withValues(alpha: 0.2), AppTheme.primaryColor.withValues(alpha: 0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCargoPie() {
    return _buildSectionContainer(
      title: "Yük Dağılımı",
      subtitle: "Taşınan mal grupları",
      icon: Icons.pie_chart_rounded,
      child: SizedBox(
        height: 300,
        child: cargoTypeDistribution.isEmpty
            ? Center(child: Text("Veri yok", style: TextStyle(color: Colors.grey[400])))
            : PieChart(
                PieChartData(
                  sections: cargoTypeDistribution.entries.map((e) {
                    final index = cargoTypeDistribution.keys.toList().indexOf(e.key);
                    final colors = [
                      const Color(0xFF6366F1),
                      const Color(0xFFEC4899),
                      const Color(0xFFF59E0B),
                      const Color(0xFF10B981),
                      const Color(0xFF3B82F6),
                    ];
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      title: "${e.value}",
                      color: colors[index % colors.length],
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                  sectionsSpace: 4,
                  centerSpaceRadius: 50,
                ),
              ),
      ),
    );
  }

  Widget _buildPortActivityChart() {
    final sortedPorts = portActivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topPorts = sortedPorts.take(5).toList();

    return _buildSectionContainer(
      title: "Liman Hareketliliği",
      subtitle: "En yoğun 5 lokasyon",
      icon: Icons.location_on_rounded,
      child: SizedBox(
        height: 400,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    if (val.toInt() >= topPorts.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        topPorts[val.toInt()].key,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(topPorts.length, (i) {
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: topPorts[i].value.toDouble(),
                    color: AppTheme.primaryColor,
                    width: 20,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildDriverPerformanceTable() {
    return _buildSectionContainer(
      title: "Sürücü Performans Sıralaması",
      subtitle: "Tamamlanan iş bazlı sıralama",
      icon: Icons.emoji_events_rounded,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            children: [
              _buildTableHeader("Sürücü"),
              _buildTableHeader("İş", alignRight: true),
              _buildTableHeader("KM", alignRight: true),
              _buildTableHeader("Yük", alignRight: true),
            ],
          ),
          ...driverPerformance.map((d) => TableRow(
                children: [
                   _buildTableCell(d["name"]),
                   _buildTableCell(d["jobs"].toString(), alignRight: true, isBold: true),
                   _buildTableCell("${d["km"].toStringAsFixed(0)}", alignRight: true),
                   _buildTableCell("${(d["weight"] / 1000).toStringAsFixed(1)}T", alignRight: true),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool alignRight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> _exportPdf() async {
    // Implement enhanced PDF logic in report_exporter.dart if needed
    // For now call existing
    final success = await ReportExporter.exportToPdf(
      context: context,
      jobs: filteredJobs,
      users: allUsers,
      title: "Operasyonel Analiz Raporu",
    );
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF Başarıyla Oluşturuldu")),
        );
      }
    }
  }

  Future<void> _exportExcel() async {
    final success = await ReportExporter.exportToExcel(
      context: context,
      jobs: filteredJobs,
      users: allUsers,
    );
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Excel Başarıyla Oluşturuldu")),
        );
      }
    }
  }
}
