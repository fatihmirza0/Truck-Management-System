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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.companyName, style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1E293B)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[700],
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Users"),
            Tab(text: "Jobs (God View)"),
            Tab(text: "Raw Data"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // 1. OVERVIEW
                    _buildOverviewTab(),
                    // 2. USERS
                    _buildUsersTab(),
                    // 3. JOBS
                    _buildJobsTab(),
                    // 4. RAW
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(const JsonEncoder.withIndent('  ').convert(_data)),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    final company = _data!['company'];
    final usage = _data!['usage'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text("Plan & Usage", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               ElevatedButton.icon(
                 onPressed: _updatePlanAndLimits,
                 icon: const Icon(Icons.edit_rounded, size: 16),
                 label: const Text("Edit Plan & Limits"),
                 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
               )
             ],
           ),
           const SizedBox(height: 16),
           _InfoCard(
             title: "Plan: ${company['plan'].toString().toUpperCase()}", 
             content: Column(
               children: [
                 _LimitRow(label: "Vehicles", current: usage['vehicleCount'], limit: company['limits']?['vehicleCount'] ?? 10),
                 _LimitRow(label: "Dispatchers", current: usage['dispatchCount'], limit: company['limits']?['dispatchCount'] ?? 3),
                 _LimitRow(label: "Managers", current: usage['managerCount'], limit: company['limits']?['managerCount'] ?? 1),
               ],
             )
           ),
           const SizedBox(height: 32),
           const Text("Company Info", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           _InfoCard(
             title: "Details",
             content: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text("Name: ${company['name']}"),
                 Text("ID: ${company['id']}"),
                 Text("Owner ID: ${company['ownerId']}"),
                 Text("Created At: ${company['createdAt']}"),
                 Text("Status: ${company['status']}"),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final users = _data!['users'] as List;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[50], 
              child: Text(user['role'][0].toUpperCase(), style: TextStyle(color: Colors.blue[700])),
            ),
            title: Text(user['name'] ?? "No Name"),
            subtitle: Text("${user['email']} • ${user['role']}"),
            trailing: Chip(
              label: Text(user['jobStatus'] ?? 'idle'),
              backgroundColor: user['jobStatus'] == 'busy' ? Colors.orange[50] : Colors.green[50],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobsTab() {
    final jobs = _data!['recentJobs'] as List;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(job['referenceNo'] ?? "JOB-???"),
            subtitle: Text("${job['route']?['loadPort']} -> ${job['route']?['unloadPort']}"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(job['status'] ?? 'unknown', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget content;
  const _InfoCard({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const Divider(height: 32),
          content,
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  final String label;
  final int current;
  final int limit;

  const _LimitRow({required this.label, required this.current, required this.limit});

  @override
  Widget build(BuildContext context) {
    final isOver = current >= limit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Row(
            children: [
              Text("$current / $limit", style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOver ? Colors.red : Colors.green,
              )),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(
                  value: (limit > 0) ? (current / limit).clamp(0.0, 1.0) : 0,
                  backgroundColor: Colors.grey[100],
                  valueColor: AlwaysStoppedAnimation(isOver ? Colors.red : Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
