import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../config/app_config.dart';
import '../../../widgets/animated/animated_widgets.dart';

class ManagerHomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  const ManagerHomePage({super.key, this.onNavigate});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse(AppConfig.getManagerDashboardUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      final decoded = jsonDecode(response.body);
      if (decoded['success'] == true) {
        setState(() {
          _data = decoded;
          _isLoading = false;
        });
      } else {
        throw Exception(decoded['error'] ?? "Failed to fetch data");
      }
    } catch (e) {
      debugPrint("❌ Dashboard Data Error: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            ),
            SizedBox(height: 16),
            Text(
              "Veriler hazırlanıyor...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh),
                label: const Text("Tekrar Dene"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              )
            ],
          ),
        ),
      );
    }

    final stats = _data!['stats'];
    final goals = _data!['goals'];
    final recentJobs = _data!['recentJobs'] as List;
    final distribution = stats['distribution'] ?? {};

    return Container(
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isMobile = width < 600;
          final isTablet = width >= 600 && width < 1024;
          final isDesktop = width >= 1024;

          return RefreshIndicator(
            onRefresh: _fetchDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : (isTablet ? 24 : 40),
                vertical: isMobile ? 16 : 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernHeader(isMobile, isTablet),
                  SizedBox(height: isMobile ? 20 : 32),
                  _buildMainKPIs(stats, width),
                  SizedBox(height: isMobile ? 20 : 32),
                  _buildQuickActions(isMobile),
                  SizedBox(height: isMobile ? 20 : 32),

                  // Responsive Layout
                  if (isDesktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildOperationalStatus(distribution, isMobile),
                              const SizedBox(height: 24),
                              _buildRecentActivity(recentJobs, isMobile),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildGoalsProgress(goals, stats, isMobile),
                              const SizedBox(height: 24),
                              _buildFleetSnapshot(stats, isMobile),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Mobile & Tablet Layout
                    _buildOperationalStatus(distribution, isMobile),
                    const SizedBox(height: 24),
                    _buildGoalsProgress(goals, stats, isMobile),
                    const SizedBox(height: 24),
                    _buildFleetSnapshot(stats, isMobile),
                    const SizedBox(height: 24),
                    _buildRecentActivity(recentJobs, isMobile),
                  ],

                  SizedBox(height: isMobile ? 24 : 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(bool isMobile, bool isTablet) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting = "İyi Günler";
    String emoji = "👋";

    if (hour >= 6 && hour < 11) {
      greeting = "Günaydın";
      emoji = "🌅";
    } else if (hour >= 11 && hour < 18) {
      greeting = "İyi Günler";
      emoji = "☀️";
    } else if (hour >= 18 && hour < 23) {
      greeting = "İyi Akşamlar";
      emoji = "🌆";
    } else {
      greeting = "İyi Geceler";
      emoji = "🌙";
    }

    return SlideInWidget(
      begin: const Offset(0, -0.3),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 20 : (isTablet ? 28 : 32)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$greeting $emoji",
                        style: TextStyle(
                          fontSize: isMobile ? 22 : (isTablet ? 26 : 28),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sistem tam kapasite çalışıyor",
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.blueGrey[200],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "ONLINE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy', 'tr').format(now),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainKPIs(Map<String, dynamic> stats, double width) {
    final isMobile = width < 600;
    final isTablet = width >= 600 && width < 1024;

    int crossAxisCount = 2;
    double aspectRatio = 2.6; // Was 2.8
    double spacing = 12;

    if (width >= 1024) {
      crossAxisCount = 4;
      aspectRatio = 3.2; // Was 3.5
      spacing = 16;
    } else if (isTablet) {
      crossAxisCount = 2;
      aspectRatio = 2.3; // Was 2.5
      spacing = 12;
    } else {
      crossAxisCount = 2;
      aspectRatio = 2.0; // Was 2.2
      spacing = 10;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: aspectRatio,
      children: [
        _ModernStatCard(
          title: "Bekleyen İşler",
          value: stats['distribution']?['pending']?.toString() ?? "0",
          icon: Icons.hourglass_empty_rounded,
          color: Colors.amber,
          trend: "Onay Bekliyor",
          isMobile: isMobile,
        ),
        _ModernStatCard(
          title: "Bugünkü Performans",
          value: stats['completedJobsToday'].toString(),
          icon: Icons.trending_up_rounded,
          color: Colors.green,
          trend: "Tamamlanan",
          isMobile: isMobile,
        ),
        _ModernStatCard(
          title: "Aylık Toplam",
          value: stats['completedJobsMonth'].toString(),
          icon: Icons.bar_chart_rounded,
          color: Colors.indigo,
          trend: "Bu Ay",
          isMobile: isMobile,
        ),
        _ModernStatCard(
          title: "Aktif Sürücüler",
          value: "${stats['activeDrivers']}/${stats['totalDrivers']}",
          icon: Icons.drive_eta_rounded,
          color: Colors.purple,
          trend: "Çevrimiçi",
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Hızlı Erişim",
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: isMobile ? 12 : 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _QuickActionBtn(
                label: "Yeni Personel",
                icon: Icons.person_add_alt_1_rounded,
                color: Colors.blue,
                onTap: () => widget.onNavigate?.call(4),
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 12 : 16),
              _QuickActionBtn(
                label: "Filo Yönetimi",
                icon: Icons.local_shipping_rounded,
                color: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Filo Yönetimi yakında eklenecek."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 12 : 16),
              _QuickActionBtn(
                label: "Rapor Al",
                icon: Icons.analytics_rounded,
                color: Colors.teal,
                onTap: () => widget.onNavigate?.call(6),
                isMobile: isMobile,
              ),
              SizedBox(width: isMobile ? 12 : 16),
              _QuickActionBtn(
                label: "Ayarlar",
                icon: Icons.settings_rounded,
                color: Colors.blueGrey,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Ayarlar sayfası henüz hazır değil."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                isMobile: isMobile,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalStatus(Map<dynamic, dynamic> distribution, bool isMobile) {
    final total = ((distribution['pending'] ?? 0) +
        (distribution['approved'] ?? 0) +
        (distribution['completed'] ?? 0));

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Operasyonel Durum",
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Toplam: $total",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: isMobile ? 8 : 12,
              child: Row(
                children: [
                  if ((distribution['pending'] ?? 0) > 0)
                    Expanded(
                      flex: (distribution['pending'] as num).toInt(),
                      child: Container(color: Colors.amber),
                    ),
                  if ((distribution['approved'] ?? 0) > 0)
                    Expanded(
                      flex: (distribution['approved'] as num).toInt(),
                      child: Container(color: Colors.blue),
                    ),
                  if ((distribution['completed'] ?? 0) > 0)
                    Expanded(
                      flex: (distribution['completed'] as num).toInt(),
                      child: Container(color: Colors.green),
                    ),
                  if (total == 0)
                    Expanded(
                      child: Container(color: Colors.grey[200]),
                    ),
                ],
              ),
            ),
          ),

          SizedBox(height: isMobile ? 16 : 20),

          // Status Cards
          Wrap(
            spacing: isMobile ? 8 : 12,
            runSpacing: isMobile ? 8 : 12,
            children: [
              _StatusChip(
                label: "Beklemede",
                count: distribution['pending'] ?? 0,
                color: Colors.amber,
                isMobile: isMobile,
              ),
              _StatusChip(
                label: "Onaylı",
                count: distribution['approved'] ?? 0,
                color: Colors.blue,
                isMobile: isMobile,
              ),
              _StatusChip(
                label: "Tamamlanan",
                count: distribution['completed'] ?? 0,
                color: Colors.green,
                isMobile: isMobile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(List recentJobs, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Son Aktiviteler",
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (recentJobs.isNotEmpty)
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text("Tümü"),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                  ),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),

          if (recentJobs.isEmpty)
            _buildEmptyState(isMobile)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentJobs.length > 5 ? 5 : recentJobs.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = recentJobs[index];
                return _ActivityItem(job: job, isMobile: isMobile);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isMobile ? 32 : 40),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: isMobile ? 56 : 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            const Text(
              "Henüz bir aktivite yok",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsProgress(
      Map<String, dynamic> goals,
      Map<String, dynamic> stats,
      bool isMobile,
      ) {
    final target = (goals['monthlyJobTarget'] ?? 0).toDouble();
    final current = (stats['completedJobsMonth'] ?? 0).toDouble();
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Aylık Hedef",
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_rounded,
                  color: Colors.white70,
                  size: isMobile ? 20 : 22,
                ),
                onPressed: _showGoalsEditor,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 24 : 32),

          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: isMobile ? 120 : 140,
                  height: isMobile ? 120 : 140,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: isMobile ? 10 : 12,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "%${(progress * 100).toInt()}",
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Tamamlandı",
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: isMobile ? 24 : 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _GoalStatRow(
                  label: "Mevcut",
                  value: current.toInt().toString(),
                  color: const Color(0xFF38BDF8),
                  isMobile: isMobile,
                ),
                Divider(
                  color: Colors.white.withOpacity(0.1),
                  height: 24,
                ),
                _GoalStatRow(
                  label: "Hedef",
                  value: target.toInt().toString(),
                  color: Colors.white70,
                  isMobile: isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFleetSnapshot(Map<String, dynamic> stats, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Filo Özeti",
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          _FleetItem(
            label: "Kayıtlı Araçlar",
            value: stats['totalVehicles'].toString(),
            icon: Icons.local_shipping_rounded,
            color: Colors.blue,
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),

          _FleetItem(
            label: "Toplam Sürücü",
            value: stats['totalDrivers'].toString(),
            icon: Icons.people_alt_rounded,
            color: Colors.indigo,
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),

          _FleetItem(
            label: "Aktif Görevler",
            value: stats['activeJobs'].toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: Colors.orange,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  void _showGoalsEditor() {
    final targetController = TextEditingController(
      text: _data!['goals']['monthlyJobTarget'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text("Hedef Belirle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Bu ay tamamlanmasını istediğiniz toplam iş sayısını belirleyin.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: targetController,
              decoration: InputDecoration(
                labelText: "Aylık İş Hedefi",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.flag_rounded),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTarget = int.tryParse(targetController.text) ?? 0;
              await _updateGoals(newTarget);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGoals(int jobTarget) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      await http.post(
        Uri.parse(AppConfig.updateCompanyGoalsUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "monthlyJobTarget": jobTarget,
          "monthlyRevenueTarget": 0
        }),
      );
      _fetchDashboardData();
    } catch (e) {
      debugPrint("Update goals error: $e");
    }
  }
}

// Widget Components
class _ModernStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isMobile;

  const _ModernStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 12 : 14,
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 8 : 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isMobile ? 18 : 20),
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.blueGrey[400],
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 6 : 8,
                vertical: isMobile ? 4 : 5,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: color.withOpacity(0.2),
                ),
              ),
              child: Text(
                trend,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isMobile;

  const _QuickActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 18 : 20),
            SizedBox(width: isMobile ? 8 : 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 13 : 14,
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isMobile;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 8 : 10,
            height: isMobile ? 8 : 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 12 : 13,
              color: const Color(0xFF475569),
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final dynamic job;
  final bool isMobile;

  const _ActivityItem({
    required this.job,
    required this.isMobile,
  });

  String _formatTs(dynamic timestamp) {
    try {
      if (timestamp is String) {
        return DateFormat('HH:mm').format(DateTime.parse(timestamp));
      }
      if (timestamp is Map && timestamp['_seconds'] != null) {
        return DateFormat('HH:mm').format(
          DateTime.fromMillisecondsSinceEpoch(
            timestamp['_seconds'] * 1000,
          ),
        );
      }
      return "--:--";
    } catch (e) {
      return "--:--";
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = job['status']?.toString().toLowerCase() ?? "";
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;

    if (status == "pending") {
      statusColor = Colors.amber;
      statusIcon = Icons.access_time_rounded;
    } else if (status == "approved") {
      statusColor = Colors.blue;
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (status == "completed") {
      statusColor = Colors.green;
      statusIcon = Icons.done_all_rounded;
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: isMobile ? 16 : 18,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['referenceNo'] ?? "İş No Yok",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${job['driverName'] ?? 'Atanmadı'} • ${job['cargo']?['type'] ?? 'Genel'}",
                  style: TextStyle(
                    color: Colors.blueGrey[400],
                    fontSize: isMobile ? 11 : 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatTs(job['timestamps']?['createdAt']),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isMobile;

  const _GoalStatRow({
    required this.label,
    required this.value,
    required this.color,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _FleetItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isMobile;

  const _FleetItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: isMobile ? 18 : 20,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }}