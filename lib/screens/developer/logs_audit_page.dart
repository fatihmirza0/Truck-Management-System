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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Search Box
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!)
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search logs by ID, name or company...",
                              prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Type Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!)
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF475569)),
                            onChanged: (val) => setState(() => _selectedType = val!),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text("All Activities")),
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
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                
                // List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _filteredLogs.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
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
                    "System Audit",
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
        title: const Text("System Audit", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
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
      return DateFormat('EEE, MMM d • h:mm a').format(date);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = log['type'] ?? 'INFO';
    Color color;
    IconData icon;
    Color bgColor;

    switch (type) {
      case 'JOB_CREATED':
        color = const Color(0xFF2563EB); // Blue
        bgColor = const Color(0xFFEFF6FF);
        icon = Icons.work_rounded;
        break;
      case 'USER_CREATED':
        color = const Color(0xFF16A34A); // Green
        bgColor = const Color(0xFFF0FDF4);
        icon = Icons.person_add_rounded;
        break;
      case 'COMPANY_CREATED':
        color = const Color(0xFF9333EA); // Purple
        bgColor = const Color(0xFFFAF5FF);
        icon = Icons.business_rounded;
        break;
      default:
        color = const Color(0xFF64748B); // Slate
        bgColor = const Color(0xFFF1F5F9);
        icon = Icons.info_rounded;
    }

    // Company Name (backend should provide, else fallback to ID)
    final companyName = log['companyName'] ?? log['companyId'] ?? 'Unknown Company';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Show details
            showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(type, style: const TextStyle(fontSize: 16))]),
                  content: SingleChildScrollView(
                      child: Text(
                          log['details'] != null
                              ? const JsonEncoder.withIndent('  ').convert(log['details'])
                              : 'No structured details available'
                      )
                  ),
                  actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Close"))],
                )
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log['message'] ?? 'No Message',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Text(
                             _formatDate(log['timestamp']),
                             style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  companyName,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
