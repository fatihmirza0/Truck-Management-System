// ============================================
// MODERN ENTERPRISE USERS PAGE - REFINED DESIGN
// Enhanced visual hierarchy & micro-interactions
// ============================================
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'user_detail_page.dart';

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
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSearchBar(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _buildSegmentedControl(),
                    const Spacer(),
                    if (isDesktop) _buildViewModeSelector(),
                  ],
                ),
                const SizedBox(height: 28),
                Expanded(child: _buildUserList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REFINED HEADER with gradient accent
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.people_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Kullanıcı Yönetimi",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Şoför ve dispatch kullanıcılarını yönetin",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ENHANCED SEARCH BAR with focus state
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _searchHint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (search.isNotEmpty)
            IconButton(
              onPressed: _clear,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.close_rounded, size: 18),
              ),
              color: const Color(0xFF64748B),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REFINED SEGMENTED CONTROL with smooth transitions
  // ---------------------------------------------------------------------------
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton("driver", "Şoförler", Icons.local_shipping_rounded),
          const SizedBox(width: 4),
          _buildTabButton("dispatch", "Dispatch", Icons.headset_mic_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(String key, String label, IconData icon) {
    final selected = _role == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _role = key;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
            )
                : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REFINED VIEW MODE SELECTOR
  // ---------------------------------------------------------------------------
  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
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
            padding: const EdgeInsets.all(10),
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
              size: 20,
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
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
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
  // MODE 1: Detailed List - ENHANCED DESIGN
  // ---------------------------------------------------------------------------
  Widget _buildDetailedList(List<Map<String, dynamic>> users) {
    return ListView.separated(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 6),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ICON
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDriver
                        ? Icons.local_shipping_outlined
                        : Icons.support_agent_outlined,
                    size: 18,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(width: 14),

                // NAME + INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (u['name'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDriver
                            ? "Araç Plakası: ${(u['plateNumber'] ?? "-")}"
                            : (u['email'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MODE 2: Compact Grid - ENHANCED
  // ---------------------------------------------------------------------------
  Widget _buildCompactGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 3.6,
      ),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? '') == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDriver
                        ? Icons.local_shipping_outlined
                        : Icons.support_agent_outlined,
                    size: 18,
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDriver
                            ? (u['plateNumber'] ?? "-").toString()
                            : (u['phone'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
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

  // ---------------------------------------------------------------------------
  // MODE 3: Dense Grid - ENHANCED
  // ---------------------------------------------------------------------------
  Widget _buildDenseGrid(List<Map<String, dynamic>> users) {
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 4.4,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Icon(
                  isDriver
                      ? Icons.local_shipping_outlined
                      : Icons.support_agent_outlined,
                  size: 16,
                  color: const Color(0xFF475569),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (u['name'] ?? "-").toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (isDriver)
                  Text(
                    (u['plateNumber'] ?? "-").toString(),
                    style: const TextStyle(
                      fontSize: 12,
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

  // ---------------------------------------------------------------------------
  // UI HELPERS - REFINED
  // ---------------------------------------------------------------------------
  Widget _chipInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF8FAFC),
            const Color(0xFFE2E8F0).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: -0.1,
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
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0).withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: Icon(
                search.isNotEmpty ? Icons.search_off_rounded : Icons.people_rounded,
                size: 72,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              search.isNotEmpty ? "Farklı bir arama terimi deneyin" : "Yeni kullanıcılar eklemek için yönetim panelini kullanın",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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