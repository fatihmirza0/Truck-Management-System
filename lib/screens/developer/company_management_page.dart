import 'dart:convert';
import 'package:flutter/material.dart';
// animate_do removed

import '../../services/developer_auth_service.dart';
import '../../utils/page_transitions.dart';
import 'developer_dashboard.dart';
import 'company_detail_page.dart';

class CompanyManagementPage extends StatefulWidget {
  final bool isEmbedded;
  const CompanyManagementPage({super.key, this.isEmbedded = false});

  @override
  State<CompanyManagementPage> createState() => _CompanyManagementPageState();
}

class _CompanyManagementPageState extends State<CompanyManagementPage> {
  final _authService = DeveloperAuthService();
  bool _isLoading = true;
  List<dynamic> _companies = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  Future<void> _fetchCompanies() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.makeGetRequest('getCompaniesHttp');
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        setState(() {
          _companies = data['companies'];
          _isLoading = false;
        });
      } else {
        throw Exception(data['error']);
      }
    } catch (e) {
      if (e.toString().contains('Session expired') || e.toString().contains('Not authenticated')) {
        if (!widget.isEmbedded) _logout(); // Only logout if standalone
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

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> get _filteredCompanies {
    if (_searchController.text.isEmpty) return _companies;
    final query = _searchController.text.toLowerCase();
    return _companies.where((c) {
      final name = (c['name'] ?? '').toLowerCase();
      final email = (c['ownerEmail'] ?? '').toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Content body
    Widget content = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!)
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: "Search companies by name or email...",
                            prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    
                    // List
                    Expanded(
                      child: _filteredCompanies.isEmpty
                          ? const Center(child: Text("No companies match your search"))
                          : ListView.separated(
                              padding: const EdgeInsets.all(24),
                              itemCount: _filteredCompanies.length,
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final company = _filteredCompanies[index];
                                return _CompanyListItem(
                                    company: company,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        SlidePageRoute(
                                          page: CompanyDetailPage(
                                            companyId: company['id'],
                                            companyName: company['name'] ?? "Unknown",
                                          ),
                                        ),
                                      ).then((_) => _fetchCompanies());
                                    },
                                  );
                              },
                            ),
                    ),
                  ],
                );

    if (widget.isEmbedded) {
      return Column(
        children: [
           // Header for Embedded View
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
                    "System Companies",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: "Refresh List",
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
                    onPressed: _fetchCompanies,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showCreateCompanyDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text("Create Company"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
        ],
      );
    }

    // Standalone Scaffold (Legacy/Backup)
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Companies", style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: BackButton(color: const Color(0xFF1E293B), onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DeveloperDashboard()));
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
            onPressed: _fetchCompanies,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: content,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCompanyDialog,
        label: const Text("New Company"),
        icon: const Icon(Icons.add_rounded),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _showCreateCompanyDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    
    String selectedPlan = 'starter';
    final vehicleController = TextEditingController(text: "10");
    final dispatchController = TextEditingController(text: "3");
    final managerController = TextEditingController(text: "1");

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Create New Company"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: "Company Name", prefixIcon: Icon(Icons.business))),
                  const SizedBox(height: 12),
                  TextField(controller: emailController, decoration: const InputDecoration(labelText: "Owner Email", prefixIcon: Icon(Icons.email))),
                  const SizedBox(height: 12),
                  TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Owner Password", prefixIcon: Icon(Icons.lock)), obscureText: true),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: selectedPlan,
                    decoration: const InputDecoration(labelText: "Plan", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "starter", child: Text("Starter (10 Veh, 3 Disp)")),
                      DropdownMenuItem(value: "pro", child: Text("Pro (50 Veh, 10 Disp)")),
                      DropdownMenuItem(value: "custom", child: Text("Custom Limits")),
                    ],
                    onChanged: (val) => setState(() => selectedPlan = val!),
                  ),
                  if (selectedPlan == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: vehicleController, decoration: const InputDecoration(labelText: "Vehicles"), keyboardType: TextInputType.number)),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: dispatchController, decoration: const InputDecoration(labelText: "Dispatchers"), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: managerController, decoration: const InputDecoration(labelText: "Managers"), keyboardType: TextInputType.number),
                  ]
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  _createCompany(
                    name: nameController.text,
                    email: emailController.text,
                    password: passwordController.text,
                    plan: selectedPlan,
                    vehicleLimit: int.tryParse(vehicleController.text) ?? 10,
                    dispatchLimit: int.tryParse(dispatchController.text) ?? 3,
                    managerLimit: int.tryParse(managerController.text) ?? 1,
                  );
                },
                child: const Text("Create"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _createCompany({
    required String name,
    required String email,
    required String password,
    required String plan,
    required int vehicleLimit,
    required int dispatchLimit,
    required int managerLimit,
  }) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> body = {
        "companyName": name,
        "ownerEmail": email,
        "ownerPassword": password,
        "plan": plan,
      };

      if (plan == 'custom') {
        body['limits'] = {
           "vehicleCount": vehicleLimit,
           "dispatchCount": dispatchLimit,
           "managerCount": managerLimit
        };
      }

      final response = await _authService.makePostRequest('createCompanyHttp', body);
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Company created successfully"), backgroundColor: Colors.green));
        _fetchCompanies();
      } else {
        throw Exception(data['error'] ?? "Server Error");
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
}

class _CompanyListItem extends StatelessWidget {
  final Map<String, dynamic> company;
  final VoidCallback onTap;

  const _CompanyListItem({required this.company, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = company['status'] ?? 'unknown';
    final isActive = status == 'active';
    final plan = (company['plan'] ?? 'starter').toString().toUpperCase();

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blue[50] : Colors.red[50], 
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                       company['name'] != null ? company['name'][0].toUpperCase() : '?',
                       style: TextStyle(
                          fontSize: 20, 
                          fontWeight: FontWeight.bold, 
                          color: isActive ? Colors.blue[700] : Colors.red[700]
                       )
                    )
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                         children: [
                             Flexible(
                               child: Text(
                                  company['name'] ?? "No Name",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                               ),
                             ),
                             if (!isActive)
                                Container(
                                   margin: const EdgeInsets.only(left: 8),
                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                   decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(4)
                                   ),
                                   child: const Text("INACTIVE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                         ]
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // "Plan: $plan • ${company['ownerEmail'] ?? 'No Email'}",
                        // Simplified for cleaner look
                        company['ownerEmail'] ?? 'No Email',
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                   crossAxisAlignment: CrossAxisAlignment.end,
                   children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(plan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(height: 4),
                      Text("${company['limits']?['vehicleCount'] ?? 10} Veh • ${company['limits']?['dispatchCount'] ?? 3} Disp", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                   ]
                ),
                const SizedBox(width: 16),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
