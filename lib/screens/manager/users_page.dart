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
  final TextEditingController _filterController = TextEditingController();

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Filtrele"),
        content: TextField(
          controller: _filterController,
          decoration: const InputDecoration(
            hintText: "İsim veya plaka girin...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                searchQuery = _filterController.text.trim().toLowerCase();
              });
              Navigator.pop(ctx);
            },
            child: const Text("Uygula"),
          ),
        ],
      ),
    );
  }

  void _clearFilter() {
    setState(() {
      searchQuery = '';
      _filterController.clear();
    });
  }

  Widget _buildUserList(BuildContext context, String role) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var users = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final name = (data['name'] ?? '').toString().toLowerCase();
          final plate = (data['plateNumber'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || plate.contains(searchQuery);
        }).toList();

        if (users.isEmpty) {
          return const Center(
            child: Text(
              "Kayıt bulunamadı.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final doc = users[i];
            final data = doc.data();

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserDetailPage(
                      userId: doc.id,
                      data: data,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffe2e8f0)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
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
                        color:
                        role == 'driver' ? Colors.blueAccent : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  data['email'] ?? '-',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
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
                                          size: 14,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        data['plateNumber'],
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey, size: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _filterController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: "İsim veya plaka ara...",
                      hintStyle:
                      const TextStyle(color: Colors.black45, fontSize: 14),
                      filled: true,
                      fillColor: const Color(0xfff8fafc),
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(
                        borderSide:
                        const BorderSide(color: Color(0xffe2e8f0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        searchQuery = val.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: "Filtreyi temizle",
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: _clearFilter,
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: const TabBar(
              indicatorColor: Color(0xff2563eb),
              labelColor: Color(0xff2563eb),
              unselectedLabelColor: Colors.grey,
              labelStyle:
              TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(text: "Şoförler"),
                Tab(text: "Dispatch"),
              ],
            ),
          ),
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
