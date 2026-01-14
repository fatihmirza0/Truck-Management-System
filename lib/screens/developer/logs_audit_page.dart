import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/developer_auth_service.dart';
import 'developer_login_page.dart';

class LogsAuditPage extends StatefulWidget {
  const LogsAuditPage({super.key});

  @override
  State<LogsAuditPage> createState() => _LogsAuditPageState();
}

class _LogsAuditPageState extends State<LogsAuditPage> {
  final _authService = DeveloperAuthService();
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.makeGetRequest('getSystemLogsHttp');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _logs = data['logs'];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error']);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Logs & Audit", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 30),
            child: _LogCard(log: log),
          );
        },
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final type = log['type'] ?? 'INFO';
    Color color;
    IconData icon;

    switch (type) {
      case 'JOB_CREATED':
        color = Colors.blue;
        icon = Icons.work_outline;
        break;
      case 'USER_CREATED':
        color = Colors.green;
        icon = Icons.person_add_alt_1;
        break;
      case 'COMPANY_CREATED':
        color = Colors.purple;
        icon = Icons.business;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info_outline;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(log['message'] ?? 'No Message', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(log['timestamp'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Text("Company: ${log['companyId'] ?? 'Unknown'}", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
          ],
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[300]),
        onTap: () {
          // Show raw details
          showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(type),
                content: SingleChildScrollView(
                    child: Text(
                        log['details'] != null
                            ? const JsonEncoder.withIndent('  ').convert(log['details'])
                            : 'No details available'
                    )
                ),
                actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close"))],
              )
          );
        },
      ),
    );
  }
}