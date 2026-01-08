import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';
import '../../user_detail/pages/user_detail_page.dart';

import '../widgets/users_page_header.dart';
import '../widgets/users_search_bar.dart';
import '../widgets/users_role_tabs.dart';
import '../widgets/users_empty_state.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animController;

  String _role = "driver";
  String search = "";
  int _viewMode = 1; // 1: Detailed List, 2: Compact Grid, 3: Dense Grid

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  String get _searchHint {
    if (_role == "dispatch") {
      return "İsim, e-posta veya telefon ile ara...";
    }
    return "İsim, e-posta veya plaka ile ara...";
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animController.forward();

    _searchController.addListener(() {
      setState(() {
        search = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      search = "";
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _animController,
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UsersPageHeader(isDesktop: isDesktop),
                SizedBox(height: isDesktop ? 16 : 12),
                UsersSearchBar(
                  controller: _searchController,
                  hintText: _searchHint,
                  onClear: _clear,
                ),
                SizedBox(height: isDesktop ? 12 : 10),
                Row(
                  children: [
                    UsersRoleTabs(
                      selectedRole: _role,
                      onRoleChanged: (role) => setState(() => _role = role),
                    ),
                    const Spacer(),
                    if (isDesktop) _buildViewModeSelector(),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                Expanded(child: _buildUserList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(1, Icons.view_agenda_rounded, "Detaylı"),
          const SizedBox(width: 4),
          _buildViewButton(2, Icons.grid_view_rounded, "Kompakt"),
          const SizedBox(width: 4),
          _buildViewButton(3, Icons.apps_rounded, "Yoğun"),
        ],
      ),
    );
  }

  Widget _buildViewButton(int mode, IconData icon, String tooltip) {
    final selected = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _viewMode = mode),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
              )
                  : null,
              borderRadius: BorderRadius.circular(8),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: const Color(0xFF1E3A5F).withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.streamUsersWithVehicle(_role),
      builder: (_, snap) {
        if (!snap.hasData) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                strokeWidth: 3,
              ),
            ),
          );
        }

        final filtered = snap.data!.where((u) {
          final name = (u['name'] ?? "").toString().toLowerCase();
          final email = (u['email'] ?? "").toString().toLowerCase();
          final phone = (u['phone'] ?? "").toString().toLowerCase();
          final plate = (u['plateNumber'] ?? "").toString().toLowerCase();

          if (_role == "dispatch") {
            return name.contains(search) || email.contains(search) || phone.contains(search);
          }
          return name.contains(search) || email.contains(search) || plate.contains(search) || phone.contains(search);
        }).toList();

        if (filtered.isEmpty) {
          return UsersEmptyState(
            message: search.isNotEmpty
                ? "Arama sonucu bulunamadı"
                : "Henüz ${_role == 'driver' ? 'şoför' : 'dispatch'} kaydı yok",
            isSearch: search.isNotEmpty,
          );
        }

        if (!isDesktop || _viewMode == 1) {
          return _buildDetailedList(filtered);
        } else if (_viewMode == 2) {
          return _buildCompactGrid(filtered);
        } else {
          return _buildDenseGrid(filtered);
        }
      },
    );
  }

  Widget _buildDetailedList(List<Map<String, dynamic>> users) {
    return ListView.separated(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                    size: 16,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (u['name'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDriver
                            ? "Araç Plakası: ${(u['plateNumber'] ?? "-")}"
                            : (u['email'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 13,
        mainAxisSpacing: 7,
        childAspectRatio: 8.7,
      ),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? '') == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                    size: 16,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (u['name'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDriver ? ("Araç Plakası: ${u['plateNumber']}" ?? "-").toString() : (u['phone'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDenseGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 5.7,
      ),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? '') == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(
                  isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                  size: 14,
                  color: const Color(0xFF475569),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (u['name'] ?? "-").toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (isDriver)
                  Text(
                    ("Araç Plakası: ${u['plateNumber']}" ?? "-").toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToDetail(String uid, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailPage(userId: uid, data: data),
      ),
    );
  }
}


