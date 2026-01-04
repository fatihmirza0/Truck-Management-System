import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';
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
            padding: EdgeInsets.all(isDesktop ? 20.0 : 16.0), // 🔥 Küçültüldü
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: isDesktop ? 16 : 12), // 🔥 Küçültüldü
                _buildSearchBar(),
                SizedBox(height: isDesktop ? 12 : 10), // 🔥 Küçültüldü
                Row(
                  children: [
                    _buildSegmentedControl(),
                    const Spacer(),
                    if (isDesktop) _buildViewModeSelector(),
                  ],
                ),
                SizedBox(height: isDesktop ? 16 : 12), // 🔥 Küçültüldü
                Expanded(child: _buildUserList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 Header - Küçültüldü
  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10), // 14 → 10
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
            ),
            borderRadius: BorderRadius.circular(12), // 16 → 12
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 8, // 12 → 8
                offset: const Offset(0, 3), // 4 → 3
              ),
            ],
          ),
          child: const Icon(
            Icons.people_rounded,
            color: Colors.white,
            size: 20, // 18 → 20 (daha okunabilir)
          ),
        ),
        const SizedBox(width: 12), // 15 → 12
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Kullanıcı Yönetimi",
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 17, // 18 → 20/17
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E3A5F),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2), // 4 → 2
              Text(
                "Şoför ve dispatch kullanıcılarını yönetin",
                style: TextStyle(
                  fontSize: isDesktop ? 13 : 12, // 13 → 12
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

  // 🔥 Search Bar - Küçültüldü
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3), // 18,4 → 14,3
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // 14 → 12
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, // 12 → 8
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // 8 → 6
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18), // 22 → 18
          ),
          const SizedBox(width: 10), // 14 → 10
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                fontSize: 14, // 15 → 14
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: _searchHint,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14, // 15 → 14
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12), // 18 → 12
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
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.close_rounded, size: 16), // 18 → 16
              ),
              color: const Color(0xFF64748B),
            ),
        ],
      ),
    );
  }

  // 🔥 Segmented Control - Küçültüldü
  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4), // 5 → 4
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10), // 14 → 10
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
        onTap: () => setState(() => _role = key),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 24,14 → 16,10
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
                blurRadius: 6, // 8 → 6
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16, // 20 → 16
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8), // 10 → 8
              Text(
                label,
                style: TextStyle(
                  fontSize: 13, // 15 → 13
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

  // 🔥 View Mode Selector - Küçültüldü
  Widget _buildViewModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4), // 5 → 4
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
            padding: const EdgeInsets.all(8), // 10 → 8
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
              size: 18, // 20 → 18
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
              padding: const EdgeInsets.all(16), // 20 → 16
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

  // 🔥 Detailed List - Küçültüldü
  Widget _buildDetailedList(List<Map<String, dynamic>> users) {
    return ListView.separated(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(vertical: 4), // 6 → 4
      separatorBuilder: (_, __) => const SizedBox(height: 6), // 8 → 6
      itemBuilder: (_, i) {
        final u = users[i];
        final uid = (u["uid"] ?? "").toString();
        final isDriver = (u['role'] ?? "") == 'driver';

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _navigateToDetail(uid, u),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 16,14 → 12,10
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
                  width: 32, // 36 → 32
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDriver ? Icons.local_shipping_outlined : Icons.support_agent_outlined,
                    size: 16, // 18 → 16
                    color: const Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(width: 10), // 14 → 10
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (u['name'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5, // 14.5 → 13.5
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3), // 4 → 3
                      Text(
                        isDriver
                            ? "Araç Plakası: ${(u['plateNumber'] ?? "-")}"
                            : (u['email'] ?? "-").toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5, // 12.5 → 11.5
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0).withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Icon(
                search.isNotEmpty ? Icons.search_off_rounded : Icons.people_rounded,
                size: 48,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              search.isNotEmpty ? "Farklı bir arama terimi deneyin" : "Yeni kullanıcılar eklemek için yönetim panelini kullanın",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
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