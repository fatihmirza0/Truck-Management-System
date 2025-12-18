// ============================================
// MODERN ENTERPRISE USERS PAGE
// FULL RESTORED UI + FirestoreService
// + Role-based search hint + refined card sizing
// ============================================
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'user_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();

  String _role = "driver";
  String search = "";
  int _viewMode = 2; // 1: Detailed List, 2: Compact Grid, 3: Dense Grid

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
    _searchController.addListener(() {
      setState(() {
        search = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
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
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSearchBar(),
              const SizedBox(height: 20),
              Row(
                children: [
                  _buildSegmentedControl(),
                  const Spacer(),
                  if (isDesktop) _buildViewModeSelector(),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildUserList()),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.people_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Kullanıcı Yönetimi",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Şoför ve dispatch kullanıcılarını yönetin",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR (role-based hint)
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _searchHint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (search.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.close, size: 20),
              color: const Color(0xFF64748B),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ROLE SEGMENTED CONTROL
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton("driver", "Şoförler", Icons.local_shipping_outlined),
          _buildTabButton("dispatch", "Dispatch", Icons.support_agent_outlined),
        ],
      ),
    );
  }

  Widget _buildTabButton(String key, String label, IconData icon) {
    final selected = _role == key;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _role = key;
              // UX: role değişince mevcut arama kalsın istiyorsan kaldırma
              // ama hint değişsin diye rebuild zaten oluyor.
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW MODE SELECTOR
  // ---------------------------------------------------------------------------
  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(1, Icons.view_agenda_outlined, "Detaylı"),
          _buildViewButton(2, Icons.grid_view_outlined, "Kompakt"),
          _buildViewButton(3, Icons.apps_outlined, "Yoğun"),
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
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1E3A5F) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
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

  // ---------------------------------------------------------------------------
  // USER LIST (FirestoreService)
  // ---------------------------------------------------------------------------
  Widget _buildUserList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService.streamUsersWithVehicle(_role),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
            ),
          );
        }

        final filtered = snap.data!.where((u) {
          final name = (u['name'] ?? "").toString().toLowerCase();
          final email = (u['email'] ?? "").toString().toLowerCase();
          final phone = (u['phone'] ?? "").toString().toLowerCase();
          final plate = (u['plateNumber'] ?? "").toString().toLowerCase();

          // role bazlı arama: dispatch'te plaka araması anlamsız
          if (_role == "dispatch") {
            return name.contains(search) || email.contains(search) || phone.contains(search);
          }
          return name.contains(search) || email.contains(search) || plate.contains(search) || phone.contains(search);
        }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            search.isNotEmpty
                ? "Arama sonucu bulunamadı"
                : "Henüz ${_role == 'driver' ? 'şoför' : 'dispatch'} kaydı yok",
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

  // ---------------------------------------------------------------------------
  // MODE 1: Detailed List (refined sizing)
  // ---------------------------------------------------------------------------
  Widget _buildDetailedList(List<Map<String, dynamic>> users) {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToDetail(uid, u),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                        size: 20,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (u['name'] ?? "-").toString(),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            runSpacing: 4,
                            spacing: 10,
                            children: [
                              _chipInfo(Icons.email_outlined, (u['email'] ?? "-").toString()),
                              _chipInfo(Icons.phone_outlined, (u['phone'] ?? "-").toString()),
                              // ✅ plaka sadece driver’da
                              if (isDriver && (u['plateNumber'] ?? "").toString().trim().isNotEmpty)
                                _chipInfo(Icons.car_rental_outlined, (u['plateNumber'] ?? "-").toString()),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 2: Compact Grid (refined sizing)
  // ---------------------------------------------------------------------------
  Widget _buildCompactGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        // daha rahat okunsun diye hafif uzattık
        childAspectRatio: 3.9,
      ),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToDetail(uid, u),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                        size: 18,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (u['name'] ?? "-").toString(),
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _buildCompactInfo(Icons.phone_outlined, (u['phone'] ?? "-").toString()),
                          const SizedBox(height: 3),
                          _buildCompactInfo(Icons.email_outlined, (u['email'] ?? "-").toString()),
                          // ✅ plaka sadece driver’da (compact'ta küçük şekilde)
                          if (isDriver && (u['plateNumber'] ?? "").toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            _buildCompactInfo(Icons.car_rental_outlined, (u['plateNumber'] ?? "-").toString()),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 3: Dense Grid (keep dense, just readable)
  // ---------------------------------------------------------------------------
  Widget _buildDenseGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4.4,
      ),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToDetail(uid, u),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                        size: 15,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (u['name'] ?? "-").toString(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isDriver && (u['plateNumber'] ?? "").toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.car_rental_outlined, size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    (u['plateNumber'] ?? "-").toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      height: 1.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------
  Widget _chipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfo(IconData icon, String? text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text ?? "-",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              search.isNotEmpty ? Icons.search_off_outlined : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            search.isNotEmpty ? "Farklı bir arama terimi deneyin" : "Yeni kullanıcılar eklemek için admin panelini kullanın",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
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
