import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_detail_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  // ------------------------------
  // FİLTRELEME
  // ------------------------------
  void _clearSearch() {
    setState(() {
      searchQuery = '';
      _searchController.clear();
    });
  }

  // ------------------------------
  // USER CARD WIDGET
  // ------------------------------
  Widget _userCard(
      Map<String, dynamic> data, String id, String role, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailPage(userId: id, data: data),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe2e8f0)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ICON BOX
            Container(
              width: 44,
              height: 22,
              decoration: BoxDecoration(
                color: role == 'driver'
                    ? Colors.blue.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                role == 'driver'
                    ? Icons.local_shipping_outlined
                    : Icons.support_agent_outlined,
                color: role == 'driver' ? Colors.blueAccent : Colors.orange,
              ),
            ),

            const SizedBox(width: 14),

            // TEXT DATA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '-',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff1e293b),
                    ),
                  ),
                  const SizedBox(height: 3),

                  // EMAIL
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['email'] ?? '-',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 3),

                  // PHONE + PLATE
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        data['phone'] ?? '-',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                      if ((data['plateNumber'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Row(
                            children: [
                              Icon(Icons.directions_car_outlined,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                data['plateNumber'],
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.grey, size: 22)
          ],
        ),
      ),
    );
  }

  // ------------------------------
  // USER LIST BUILDER (RESPONSIVE)
  // ------------------------------
  Widget _buildUserList(BuildContext context, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: role)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snap.data!.docs.where((d) {
          final data = d.data();
          final name = (data['name'] ?? '').toLowerCase();
          final plate = (data['plateNumber'] ?? '').toLowerCase();
          return name.contains(searchQuery) || plate.contains(searchQuery);
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "Kayıt bulunamadı.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        if (isDesktop(context)) {
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // geniş ekranda 2 kolon
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.4,
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              return _userCard(doc.data(), doc.id, role, context);
            },
          );
        } else {
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final doc = docs[i];
              return _userCard(doc.data(), doc.id, role, context);
            },
          );
        }
      },
    );
  }

  // ------------------------------
  // BUILD
  // ------------------------------
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // ------------------ SEARCH BAR ------------------
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      setState(() {
                        searchQuery = v.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: "İsim veya plaka ara...",
                      filled: true,
                      fillColor: const Color(0xfff1f5f9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xffd1d5db)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: "Temizle",
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              ],
            ),
          ),

          // ------------------ TABS ------------------
          Container(
            color: Colors.white,
            child: const TabBar(
              indicatorColor: Color(0xff2563eb),
              labelColor: Color(0xff2563eb),
              unselectedLabelColor: Colors.grey,
              labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: "Şoförler"),
                Tab(text: "Dispatch"),
              ],
            ),
          ),

          // ------------------ CONTENT ------------------
          Expanded(
            child: Container(
              color: const Color(0xfff5f6fa),
              child: TabBarView(
                children: [
                  _buildUserList(context, 'driver'),
                  _buildUserList(context, 'dispatch'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
