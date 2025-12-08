import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String search = "";

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  static const Color accent = Color(0xFF2563EB);

  void _clear() {
    setState(() {
      search = "";
      _searchController.clear();
    });
  }

  // ------------------------------------------------------------
  // USER CARD
  // ------------------------------------------------------------
  Widget _userCard(Map<String, dynamic> u, String uid) {
    final isDriver = u['role'] == 'driver';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailPage(
              userId: uid,   // 🔥 UID → Doğru ID gönderiyoruz
              data: u,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDriver ? Icons.local_shipping : Icons.support_agent,
                size: 26,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 16),

            // Info Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u['name'] ?? "-",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _infoRow(Icons.email_outlined, u['email']),
                  const SizedBox(height: 3),
                  _infoRow(Icons.phone_outlined, u['phone']),
                  if (isDriver && (u['plateNumber'] ?? "").isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _infoRow(Icons.directions_car, u['plateNumber']),
                    ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String? text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade600),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text ?? "-",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // USER LIST BUILDER
  // ------------------------------------------------------------
  Widget _list(String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final filtered = snap.data!.docs.where((d) {
          final u = d.data();
          final name = (u['name'] ?? "").toLowerCase();
          final plate = (u['plateNumber'] ?? "").toLowerCase();
          return name.contains(search) || plate.contains(search);
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text("Kayıt bulunamadı",
                style: TextStyle(color: Colors.black54, fontSize: 16)),
          );
        }

        return isDesktop
            ? GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 20,
            mainAxisSpacing: 18,
            childAspectRatio: 2.7,
          ),
          itemCount: filtered.length,
          itemBuilder: (_, i) =>
              _userCard(filtered[i].data(), filtered[i].id),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) =>
              _userCard(filtered[i].data(), filtered[i].id),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 10),

          // SEARCH BAR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => search = v.toLowerCase().trim()),
                    decoration: const InputDecoration(
                      hintText: "İsim veya plaka ile ara...",
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (search.isNotEmpty)
                  IconButton(
                      onPressed: _clear,
                      icon: const Icon(Icons.close, color: Colors.grey))
              ],
            ),
          ),

          const SizedBox(height: 16),

          // TABS
          const TabBar(
            indicatorColor: accent,
            labelColor: accent,
            unselectedLabelColor: Colors.grey,
            labelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: "Şoförler"),
              Tab(text: "Dispatch"),
            ],
          ),

          const SizedBox(height: 10),

          // CONTENT
          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: TabBarView(
                children: [
                  _list("driver"),
                  _list("dispatch"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
