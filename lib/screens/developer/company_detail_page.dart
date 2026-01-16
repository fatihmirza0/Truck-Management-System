import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lojistik/config/app_theme.dart';

import '../../services/developer_auth_service.dart';
import 'developer_login_page.dart';

class CompanyDetailPage extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyDetailPage({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends State<CompanyDetailPage> with SingleTickerProviderStateMixin {
  final _authService = DeveloperAuthService();
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.makeGetRequestWithQuery(
        'getCompanyFullDetailsHttp',
        {'companyId': widget.companyId},
      );
      
      final resData = jsonDecode(response.body);
      if (resData['success'] == true) {
        setState(() {
          _data = resData['data'];
          _isLoading = false;
        });
      } else {
        throw Exception(resData['error']);
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
  
  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DeveloperLoginPage()),
      (route) => false,
    );
  }
  
  Future<void> _updatePlanAndLimits() async {
    final company = _data?['company'];
    if (company == null) return;
    
    final planController = TextEditingController(text: company['plan']);
    final vehicleController = TextEditingController(text: (company['limits']?['vehicleCount'] ?? 10).toString());
    final dispatchController = TextEditingController(text: (company['limits']?['dispatchCount'] ?? 3).toString());
    final managerController = TextEditingController(text: (company['limits']?['managerCount'] ?? 1).toString());

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Plan & Limits"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: planController, decoration: const InputDecoration(labelText: "Plan (starter/pro)")),
            const SizedBox(height: 16),
            TextField(controller: vehicleController, decoration: const InputDecoration(labelText: "Vehicle Limit"), keyboardType: TextInputType.number),
            TextField(controller: dispatchController, decoration: const InputDecoration(labelText: "Dispatch Limit"), keyboardType: TextInputType.number),
            TextField(controller: managerController, decoration: const InputDecoration(labelText: "Manager Limit"), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _submitUpdate(
                plan: planController.text,
                vehicleLimit: int.tryParse(vehicleController.text) ?? 10,
                dispatchLimit: int.tryParse(dispatchController.text) ?? 3,
                managerLimit: int.tryParse(managerController.text) ?? 1,
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUpdate({required String plan, required int vehicleLimit, required int dispatchLimit, required int managerLimit}) async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.makePostRequest('updateCompanyPlanHttp', {
        "companyId": widget.companyId,
        "plan": plan,
        "limits": {
          "vehicleCount": vehicleLimit,
          "dispatchCount": dispatchLimit,
          "managerCount": managerLimit
        }
      });

      final resData = jsonDecode(response.body);
      if (resData['success'] == true) {
        _fetchDetails();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updated successfully"), backgroundColor: Colors.green));
      } else {
        throw Exception(resData['error']);
      }
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('Not authenticated')) {
        _logout();
        return;
      }
      
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: Text(widget.companyName, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB), // Blue 600
              unselectedLabelColor: const Color(0xFF64748B), // Slate 500
              indicatorColor: const Color(0xFF2563EB),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: "Overview"),
                Tab(text: "Users"),
                Tab(text: "Jobs"),
                Tab(text: "Raw Data"),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh Data",
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A)),
            onPressed: _fetchDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildUsersTab(),
                    _buildJobsTab(),
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SelectableText(const JsonEncoder.withIndent('  ').convert(_data), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    ),
                  ],
                ),
    );
  }

  Future<void> _toggleStatus() async {
    final company = _data?['company'];
    if (company == null) return;
    
    final currentStatus = company['status'] ?? 'inactive';
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
    final action = newStatus == 'active' ? 'Activate' : 'Deactivate';
    final color = newStatus == 'active' ? Colors.green : Colors.red;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action Company"),
        content: Text("Are you sure you want to $action this company?\n\nThis will ${newStatus == 'inactive' ? 'lock out all users immediately' : 'restore access'}."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(context, true), 
            child: Text(action),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _authService.makePostRequest('toggleCompanyStatusHttp', {
        'companyId': widget.companyId,
        'status': newStatus
      });
      
      final resData = jsonDecode(response.body);
      if (resData['success'] == true) {
         _fetchDetails();
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Company is now $newStatus"), backgroundColor: color));
      } else {
         throw Exception(resData['error']);
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildOverviewTab() {
    final company = _data!['company'];
    final usage = _data!['usage'];
    final isActive = company['status'] == 'active';

    // Safely extract createdAt
    String createdAtStr = 'N/A';
    if (company['createdAt'] != null) {
      if (company['createdAt'] is Map) {
         // Handle Firestore Timestamp object
         final seconds = company['createdAt']['_seconds'];
         if (seconds != null) {
            createdAtStr = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toString().split('.').first;
         } else {
            createdAtStr = company['createdAt'].toString();
         }
      } else {
         createdAtStr = company['createdAt'].toString();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // STATUS BANNER
           if (!isActive)
             Container(
               width: double.infinity,
               margin: const EdgeInsets.only(bottom: 24),
               padding: const EdgeInsets.all(16),
               decoration: BoxDecoration(
                 color: const Color(0xFFFEF2F2), // Red 50
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: const Color(0xFFFECACA)) // Red 200
               ),
               child: Row(
                 children: [
                   const Icon(Icons.report_problem_rounded, color: Color(0xFFDC2626)), // Red 600
                   const SizedBox(width: 12),
                   const Expanded(child: Text("This company is CURRENTLY INACTIVE. Access is restricted for all users.", style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.bold))),
                   ElevatedButton(
                      onPressed: _toggleStatus,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), elevation: 0),
                      child: const Text("Activate Now"),
                   )
                 ],
               ),
             ),
             
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("Subscription & Limits", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
               Row(
                 children: [
                    if (isActive)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.power_settings_new_rounded, size: 16, color: Colors.red),
                        label: const Text("Deactivate", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        onPressed: _toggleStatus,
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                     onPressed: _updatePlanAndLimits,
                     icon: const Icon(Icons.edit_rounded, size: 16),
                     label: const Text("Edit Limits"),
                     style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), elevation: 0),
                   ),
                 ],
               )
             ],
           ),
           const SizedBox(height: 24),
           
           // STATS GRID
           Row(
             children: [
               Expanded( child: _StatSummaryCard(label: "Vehicles", current: usage['vehicleCount'] ?? 0, limit: company['limits']?['vehicleCount'] ?? 10, icon: Icons.local_shipping_rounded, color: Colors.blue) ),
               const SizedBox(width: 16),
               Expanded( child: _StatSummaryCard(label: "Dispatchers", current: usage['dispatchCount'] ?? 0, limit: company['limits']?['dispatchCount'] ?? 3, icon: Icons.headset_mic_rounded, color: Colors.purple) ),
               const SizedBox(width: 16),
               Expanded( child: _StatSummaryCard(label: "Managers", current: usage['managerCount'] ?? 0, limit: company['limits']?['managerCount'] ?? 1, icon: Icons.supervisor_account_rounded, color: Colors.orange) ),
             ],
           ),

           const SizedBox(height: 48),
           const Text("Company Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
           const SizedBox(height: 16),
           Container(
             width: double.infinity,
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(
               color: Colors.white,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.grey[200]!),
               boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
             ),
             child: Column(
               children: [
                 _DetailRow(label: "Company Name", value: (company['name'] ?? 'N/A').toString()),
                 _DetailRow(label: "Company ID", value: (company['id'] ?? 'N/A').toString(), isMono: true),
                 _DetailRow(label: "Owner ID", value: (company['ownerId'] ?? 'N/A').toString(), isMono: true),
                 _DetailRow(label: "Current Plan", value: (company['plan'] ?? 'starter').toString().toUpperCase()),
                 _DetailRow(label: "Created At", value: createdAtStr),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final users = _data!['users'] as List;
    if (users.isEmpty) return const Center(child: Text("No users found", style: TextStyle(color: Colors.grey)));

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: users.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFEFF6FF), // Blue 50
              child: Text(user['role'] != null ? user['role'][0].toUpperCase() : '?', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ),
            title: Text(user['name'] ?? "No Name", style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("${user['email']} • ${user['role']}", style: TextStyle(color: Colors.grey[500])),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: user['jobStatus'] == 'busy' ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: user['jobStatus'] == 'busy' ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7)),
              ),
              child: Text(
                (user['jobStatus'] ?? 'idle').toString().toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: user['jobStatus'] == 'busy' ? const Color(0xFFC2410C) : const Color(0xFF15803D),
                )
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobsTab() {
    final jobs = _data!['recentJobs'] as List;
    if (jobs.isEmpty) return const Center(child: Text("No recent jobs", style: TextStyle(color: Colors.grey)));
    
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: jobs.length,
      separatorBuilder: (c, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined, color: Color(0xFF64748B)),
            title: Text(job['referenceNo'] ?? "JOB-???", style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text("${job['route']?['loadPort']} -> ${job['route']?['unloadPort']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(job['status'] ?? 'unknown', style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  final String label;
  final int current;
  final int limit;
  final IconData icon;
  final Color color;

  const _StatSummaryCard({required this.label, required this.current, required this.limit, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isOver = limit > 0 && current >= limit;
    final progress = limit > 0 ? (current / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("$current", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isOver ? Colors.red : const Color(0xFF0F172A))),
              Text(" / $limit", style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8), height: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(isOver ? Colors.red : color),
              minHeight: 6,
            ),
          )
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _DetailRow({required this.label, required this.value, this.isMono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: TextStyle(
            color: const Color(0xFF0F172A), 
            fontWeight: FontWeight.w600,
            fontFamily: isMono ? 'monospace' : null,
          ))),
        ],
      ),
    );
  }
}
