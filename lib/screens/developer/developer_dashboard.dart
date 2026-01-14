import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/developer_auth_service.dart';
import 'company_management_page.dart';
import 'developer_login_page.dart';
import 'logs_audit_page.dart';

class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  final _authService = DeveloperAuthService();
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

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _authService.makeGetRequest('getDashboardStatsHttp');
      
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        setState(() {
          _stats = data['stats'];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error'] ?? "Unknown error");
      }
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('Not authenticated')) {
        _logout();
        return;
      }
      
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchLogs() async {
    try {
      final response = await _authService.makeGetRequest('getSystemLogsHttp');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _recentLogs = (data['logs'] as List).take(5).toList();
        });
      }
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('Not authenticated')) {
        _logout();
        return;
      }
      debugPrint("Error fetching logs: $e");
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DeveloperLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // SIDEBAR (Simplified for Dev)
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              children: [
                const SizedBox(height: 32),
                 FadeInLeft(
                  child: const Text(
                    "DEV PANEL",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                _SidebarItem(
                  icon: Icons.dashboard_rounded,
                  label: "Dashboard",
                  isActive: true,
                  onTap: () {},
                ),
                _SidebarItem(
                  icon: Icons.business_rounded,
                  label: "Companies",
                  isActive: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CompanyManagementPage()),
                  ),
                ),
                  _SidebarItem(
                  icon: Icons.security_rounded,
                  label: "Logs & Audit",
                  isActive: false,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsAuditPage()),
                  ),
                ),
                const Spacer(),
                _SidebarItem(
                  icon: Icons.logout_rounded,
                  label: "Logout",
                  isActive: false,
                  isDestructive: true,
                  onTap: _logout,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        "Overview",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () { _fetchStats(); _fetchLogs(); },
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: "Refresh Stats",
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // STATS GRID
                                  AnimatedGrid(
                                    crossAxisCount: 4,
                                    childAspectRatio: 1.5,
                                    mainAxisSpacing: 24,
                                    crossAxisSpacing: 24,
                                    children: [
                                      _StatCard(
                                        title: "Total Companies",
                                        value: "${_stats?['totalCompanies'] ?? 0}",
                                        icon: Icons.business_rounded,
                                        color: Colors.blue,
                                        delay: 0,
                                      ),
                                      _StatCard(
                                        title: "Total Users",
                                        value: "${_stats?['totalUsers'] ?? 0}",
                                        icon: Icons.people_alt_rounded,
                                        color: Colors.purple,
                                        delay: 100,
                                      ),
                                      _StatCard(
                                        title: "Active Vehicles",
                                        value: "${_stats?['activeVehicles'] ?? 0}",
                                        icon: Icons.local_shipping_rounded,
                                        color: Colors.orange,
                                        delay: 200,
                                      ),
                                      _StatCard(
                                        title: "Jobs (24h)",
                                        value: "${_stats?['jobsLast24h'] ?? 0}",
                                        icon: Icons.work_rounded,
                                        color: Colors.green,
                                        delay: 300,
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 48),
                                  const SectionHeader(title: "Recent System Activity"),
                                  const SizedBox(height: 16),
                                  
                                  // Activity List
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: AppTheme.softShadow,
                                    ),
                                    child: _recentLogs.isEmpty
                                        ? const Padding(padding: EdgeInsets.all(24), child: Center(child: Text("No recent activity")))
                                        : ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: _recentLogs.length,
                                            separatorBuilder: (c, i) => const Divider(height: 1),
                                            itemBuilder: (context, index) {
                                              final log = _recentLogs[index];
                                              return ListTile(
                                                leading: Icon(
                                                  log['type'] == 'JOB_CREATED' ? Icons.work : Icons.info,
                                                  color: Colors.blueGrey,
                                                ),
                                                title: Text(log['message'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: Text(log['timestamp'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                                                trailing: const Icon(Icons.chevron_right, size: 16),
                                                onTap: () {
                                                   // View details if needed
                                                },
                                              );
                                            },
                                          ),
                                  ),
                                ],
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
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.redAccent : (isActive ? Colors.white : Colors.grey[400]);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: isActive ? BoxDecoration(
            border: const Border(left: BorderSide(color: Colors.blueAccent, width: 4)),
            color: Colors.blueAccent.withValues(alpha: 0.1),
          ) : null,
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
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
  final MaterialColor color;
  final int delay;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[900],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimatedGrid extends StatelessWidget {
  final int crossAxisCount;
  final double childAspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final List<Widget> children;

  const AnimatedGrid({
    super.key,
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      children: children,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
