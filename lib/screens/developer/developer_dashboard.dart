import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:intl/intl.dart';

import '../../services/developer_auth_service.dart';
import 'company_management_page.dart';
import 'logs_audit_page.dart';
import 'developer_login_page.dart';

class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  final _authService = DeveloperAuthService();
  int _currentIndex = 0;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<dynamic> _recentLogs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuthAndFetch();
  }

  Future<void> _checkAuthAndFetch() async {
    final isAuth = await _authService.isAuthenticated();
    if (!isAuth && mounted) {
      _logout();
      return;
    }
    _fetchStats();
    _fetchLogs();
  }

  // ... _fetchStats and _fetchLogs remain same, but removed from here later if specific to Home fragment
  // keeping them for now as Home fragment part
  Future<void> _fetchStats() async {
     setState(() { _isLoading = true; _error = null; });
     try {
       final response = await _authService.makeGetRequest('getDashboardStatsHttp');
       final data = jsonDecode(response.body);
       if (data['success'] == true) {
         setState(() { _stats = data['stats']; _isLoading = false; });
       }
     } catch (e) {
       if (e.toString().contains('Session expired')) { _logout(); return; }
       if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
     }
  }

  Future<void> _fetchLogs() async {
    try {
      final response = await _authService.makeGetRequest('getSystemLogsHttp');
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() { _recentLogs = (data['logs'] as List).take(5).toList(); });
      }
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeveloperLoginPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(4, 0))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1E40AF)]), // Blue 600-800
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "DEV PANEL",
                  style: TextStyle(
                    color: Color(0xFF0F172A), // Slate 900
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _SidebarItem(
            icon: Icons.dashboard_rounded,
            label: "Overview",
            isActive: _currentIndex == 0,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          _SidebarItem(
            icon: Icons.business_rounded,
            label: "Companies",
            isActive: _currentIndex == 1,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          _SidebarItem(
            icon: Icons.monitor_heart_rounded,
            label: "System Health",
            isActive: _currentIndex == 2,
            onTap: () => setState(() => _currentIndex = 2),
            badgeCount: 0, // Placeholder
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, color: Color(0xFF64748B), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Master Admin", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text("Dev Access", style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _logout,
                    child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildDashboardHome();
      case 1: return const CompanyManagementPage(isEmbedded: true); 
      case 2: return const LogsAuditPage(isEmbedded: true); 
      default: return const SizedBox();
    }
  }

  Widget _buildDashboardHome() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           const Text("Dashboard Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
           const SizedBox(height: 8),
           Text("Welcome back, Master Admin. Here is the latest system status.", style: TextStyle(fontSize: 16, color: Colors.blueGrey[400])),
           const SizedBox(height: 32),
           _buildStatsGrid(),
           const SizedBox(height: 48),
           const Text("Recent System Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
           const SizedBox(height: 16),
           _buildRecentLogsTable(),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _StatCard(
              title: "Total Companies",
              value: "${_stats?['totalCompanies'] ?? 0}",
              icon: Icons.business_rounded,
              gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
              delay: 0,
              width: (constraints.maxWidth - 72) / 4, // Approx 4 cols
            ),
            _StatCard(
              title: "Total Users",
              value: "${_stats?['totalUsers'] ?? 0}",
              icon: Icons.people_alt_rounded,
              gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
              delay: 100,
              width: (constraints.maxWidth - 72) / 4,
            ),
            _StatCard(
              title: "Active Vehicles",
              value: "${_stats?['activeVehicles'] ?? 0}",
              icon: Icons.local_shipping_rounded,
              gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
              delay: 200,
              width: (constraints.maxWidth - 72) / 4,
            ),
            _StatCard(
              title: "Jobs (24h)",
              value: "${_stats?['jobsLast24h'] ?? 0}",
              icon: Icons.work_rounded,
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              delay: 300,
              width: (constraints.maxWidth - 72) / 4,
            ),
          ],
        );
      }
    );
  }

  Widget _buildRecentLogsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: _recentLogs.isEmpty
          ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("No recent activity")))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentLogs.length,
              separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey[100]),
              itemBuilder: (context, index) {
                final log = _recentLogs[index];
                final isJob = log['type'] == 'JOB_CREATED';
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isJob ? Colors.blue[50] : Colors.orange[50], // Soft background
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isJob ? Icons.work_outline_rounded : Icons.info_outline_rounded,
                      color: isJob ? Colors.blue[700] : Colors.orange[700],
                      size: 20,
                    ),
                  ),
                  title: Text(log['message'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    DateFormat('MMM d, h:mm a').format(DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now()), 
                    style: TextStyle(fontSize: 12, color: Colors.grey[400])
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                  ),
                  onTap: () {
                      setState(() => _currentIndex = 2);
                  },
                );
              },
            ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: isActive ? BoxDecoration(
            border: const Border(left: BorderSide(color: Color(0xFF2563EB), width: 4)),
            color: const Color(0xFFEFF6FF), // Blue 50
          ) : null,
          child: Row(
            children: [
              Icon(icon, color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 22), // Blue 600 : Slate 500
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B), // Slate 900 : Slate 500
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              if (badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text("$badgeCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final int delay;
  final double width;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.delay,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width.clamp(240, 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
              ]
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.blueGrey[900],
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey[400],
            ),
          ),
        ],
      ),
    );
  }
}
