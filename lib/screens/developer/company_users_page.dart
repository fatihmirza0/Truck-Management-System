import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_permission_page.dart';

class CompanyUsersPage extends StatefulWidget {
  final String developerKey;
  final String companyId;
  final String companyName;

  const CompanyUsersPage({
    super.key,
    required this.developerKey,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyUsersPage> createState() => _CompanyUsersPageState();
}

class _CompanyUsersPageState extends State<CompanyUsersPage> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Mock URL - replace with actual
      const functionUrl = "https://us-central1-truck-dispatch-system.cloudfunctions.net/getCompanyUsersHttp";
      
      final res = await http.get(
        Uri.parse("$functionUrl?companyId=${widget.companyId}"),
        headers: {"x-developer-key": widget.developerKey},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _users = data['users'];
          _isLoading = false;
        });
      } else {
        throw Exception("Hata: ${res.statusCode} - ${res.body}");
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("${widget.companyName} Kullanıcıları"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Hata: $_error", style: TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (ctx, index) {
                    final u = _users[index];
                    final permissions = u['permissions'] ?? [];
                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Text(u['name']?[0] ?? "?", style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(u['name'] ?? 'Adsız', style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          "${u['email']} • Role: ${u['role']}\nPerms: ${permissions.length}",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_attributes, color: Colors.blueAccent),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserPermissionPage(
                                  developerKey: widget.developerKey,
                                  userId: u['id'],
                                  userName: u['name'] ?? 'Kullanıcı',
                                  currentPermissions: List<String>.from(permissions),
                                ),
                              ),
                            ).then((_) => _fetchUsers());
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
