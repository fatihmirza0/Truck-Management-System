import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserPermissionPage extends StatefulWidget {
  final String developerKey;
  final String userId;
  final String userName;
  final List<String> currentPermissions;

  const UserPermissionPage({
    super.key,
    required this.developerKey,
    required this.userId,
    required this.userName,
    required this.currentPermissions,
  });

  @override
  State<UserPermissionPage> createState() => _UserPermissionPageState();
}

class _UserPermissionPageState extends State<UserPermissionPage> {
  late Set<String> _permissions;
  bool _isSaving = false;

  // Define available permissions here
  final List<String> _availablePermissions = [
    "view_reports",
    "manage_billing",
    "delete_jobs",
    "manage_users",
    "export_data",
    "view_logs"
  ];

  @override
  void initState() {
    super.initState();
    _permissions = widget.currentPermissions.toSet();
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);

    try {
      const functionUrl = "https://us-central1-truck-dispatch-system.cloudfunctions.net/updateUserPermissionsHttp";
      
      final res = await http.post(
        Uri.parse(functionUrl),
        headers: {
          "x-developer-key": widget.developerKey,
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "userId": widget.userId,
          "permissions": _permissions.toList(),
        }),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Yetkiler güncellendi")));
        Navigator.pop(context);
      } else {
        throw Exception(res.body);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text("Hata: $e")));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("Yetkiler: ${widget.userName}"),
        actions: [
          IconButton(
            icon: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Icon(Icons.save),
            onPressed: _isSaving ? null : _savePermissions,
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _availablePermissions.length,
        itemBuilder: (ctx, index) {
          final perm = _availablePermissions[index];
          final hasPerm = _permissions.contains(perm);
          
          return SwitchListTile(
            activeColor: Colors.indigoAccent,
            contentPadding: EdgeInsets.zero,
            title: Text(perm, style: const TextStyle(color: Colors.white)),
            value: hasPerm,
            onChanged: (val) {
              setState(() {
                if (val) {
                  _permissions.add(perm);
                } else {
                  _permissions.remove(perm);
                }
              });
            },
          );
        },
      ),
    );
  }
}
