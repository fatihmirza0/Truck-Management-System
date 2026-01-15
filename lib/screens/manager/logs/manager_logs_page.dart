import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../config/app_config.dart';

class ManagerLogsPage extends StatefulWidget {
  const ManagerLogsPage({super.key});

  @override
  State<ManagerLogsPage> createState() => _ManagerLogsPageState();
}

class _ManagerLogsPageState extends State<ManagerLogsPage> {
  bool _isLoading = true;
  List<dynamic> _logs = [];
  String? _error;

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse(AppConfig.getManagerLogsUrl),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

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
      debugPrint("❌ Manager Logs Error: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredLogs {
    return _logs.where((log) {
      final typeMatches = _selectedType == 'ALL' || log['type'] == _selectedType;
      final query = _searchController.text.toLowerCase();
      final messageMatches = (log['message'] as String? ?? '').toLowerCase().contains(query);
      final descMatches = (log['description'] as String? ?? '').toLowerCase().contains(query);
      
      return typeMatches && (messageMatches || descMatches);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;

    return Column(
      children: [
        // Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Loglarda ara...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(width: 16),
                    _buildTypeDropdown(),
                    const SizedBox(width: 8),
                    _buildRefreshBtn(),
                  ],
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTypeDropdown()),
                    const SizedBox(width: 12),
                    _buildRefreshBtn(),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text("Hata: $_error", style: const TextStyle(color: Colors.red)))
              : _filteredLogs.isEmpty
              ? const Center(child: Text("Log bulunamadı."))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: width > 900 ? 40 : 16,
                    vertical: 24,
                  ),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];
                    return _LogItem(log: log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: MediaQuery.of(context).size.width < 700,
          onChanged: (val) => setState(() => _selectedType = val!),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text("Tümü")),
            DropdownMenuItem(value: 'JOB_ACTIVITY', child: Text("İş Hareketleri")),
            DropdownMenuItem(value: 'LOGIN_ACTIVITY', child: Text("Giriş Çıkış")),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshBtn() {
    return IconButton(
      icon: const Icon(Icons.refresh_rounded),
      onPressed: _fetchLogs,
      tooltip: "Yenile",
    );
  }
}

class _LogItem extends StatelessWidget {
  final Map<String, dynamic> log;
  const _LogItem({required this.log});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return DateFormat('d MMMM yyyy • HH:mm').format(date);
      }
      return timestamp.toString();
    } catch (e) {
      return timestamp.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = log['type'];
    final color = type == 'JOB_ACTIVITY' ? Colors.blue : Colors.orange;
    final icon = type == 'JOB_ACTIVITY' ? Icons.work_outline : Icons.login_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        log['message'] ?? 'Mesaj Yok',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(log['timestamp']),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  log['description'] ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
