import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// animate_do removed

import '../../services/developer_auth_service.dart';
import 'developer_dashboard.dart';

class LogsAuditPage extends StatefulWidget {
  final bool isEmbedded;
  const LogsAuditPage({super.key, this.isEmbedded = false});

  @override
  State<LogsAuditPage> createState() => _LogsAuditPageState();
}

class _LogsAuditPageState extends State<LogsAuditPage> {
  final _authService = DeveloperAuthService();
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String? _error;

  // Filter State
  String _selectedType = 'ALL';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        if (!widget.isEmbedded) _logout();
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
      MaterialPageRoute(builder: (_) => const DeveloperDashboard()),
      (route) => false,
    );
  }

  List<dynamic> get _filteredLogs {
    return _logs.where((log) {
      final typeMatches = _selectedType == 'ALL' || log['type'] == _selectedType;
      final query = _searchController.text.toLowerCase();
      final messageMatches = (log['message'] as String? ?? '').toLowerCase().contains(query);
      final companyMatches = (log['companyName'] as String? ?? log['companyId'] as String? ?? '').toLowerCase().contains(query);
      
      return typeMatches && (messageMatches || companyMatches);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
          : Column(
              children: [
                // Filter Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Search
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search logs...",
                            prefixIcon: const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Type Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            onChanged: (val) => setState(() => _selectedType = val!),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text("All Types")),
                              DropdownMenuItem(value: 'JOB_CREATED', child: Text("Jobs")),
                              DropdownMenuItem(value: 'USER_CREATED', child: Text("Users")),
                              DropdownMenuItem(value: 'COMPANY_CREATED', child: Text("Companies")),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                
                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = _filteredLogs[index];
                      return _LogCard(log: log);
                    },
                  ),
                ),
              ],
            );

    if (widget.isEmbedded) {
      return Column(
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
                    "Logs & Audit",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
                    onPressed: _fetchLogs,
                  ),
                ],
              ),
            ),
            Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Logs & Audit", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF1E293B), onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeveloperDashboard()));
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: _fetchLogs,
          ),
        ],
      ),
      body: content,
    );
  }
}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogCard({required this.log});

  String _formatDate(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return timestamp;
    }
  }

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

    // Company Name (backend should provide, else fallback to ID)
    final companyName = log['companyName'] ?? log['companyId'] ?? 'Unknown Company';

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
        title: Text(log['message'] ?? 'No Message', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatDate(log['timestamp']),
               style: TextStyle(color: Colors.grey[500], fontSize: 12)
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                companyName,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
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
