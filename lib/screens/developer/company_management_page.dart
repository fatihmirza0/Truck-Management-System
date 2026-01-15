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

  @override
  Widget build(BuildContext context) {
    // Content body
    Widget content = _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text("Error: $_error", style: const TextStyle(color: Colors.red)))
              : _companies.isEmpty
                  ? const Center(child: Text("No companies found"))
                  : GridView.builder(
                      padding: const EdgeInsets.all(32),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: _companies.length,
                      itemBuilder: (context, index) {
                        final company = _companies[index];
                        // Removed FadeInUp
                        return _CompanyCard(
                            company: company,
                            onTap: () {
                              Navigator.push(
                                context,
                                SlidePageRoute( // Custom Transition
                                  page: CompanyDetailPage(
                                    companyId: company['id'],
                                    companyName: company['name'] ?? "Unknown",
                                  ),
                                ),
                              );
                            },
                          );
                      },
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
                    "Companies",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1E293B)),
                    onPressed: _fetchCompanies,
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton.small(
                    onPressed: _showCreateCompanyDialog,
                    backgroundColor: const Color(0xFF1E293B),
                    child: const Icon(Icons.add_rounded),
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
        backgroundColor: const Color(0xFF1E293B),
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

class _CompanyCard extends StatelessWidget {
  final Map<String, dynamic> company;
  final VoidCallback onTap;

  const _CompanyCard({required this.company, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = company['status'] ?? 'unknown';
    final isActive = status == 'active';
    final plan = (company['plan'] ?? 'starter').toString().toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.blue[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business_rounded, 
                      color: isActive ? Colors.blue[700] : Colors.grey,
                      size: 24
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company['name'] ?? "No Name",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green[50] : Colors.red[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: isActive ? Colors.green[200]! : Colors.red[200]!),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple[50],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple[200]!),
                              ),
                              child: Text(
                                plan,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Limits: ${company['limits']?['vehicleCount'] ?? 10} Veh • ${company['limits']?['dispatchCount'] ?? 3} Disp",
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey[400]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
