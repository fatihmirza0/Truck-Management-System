// lib/screens/manager/users_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  Future<void> _deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
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

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return Center(
            child: Text(
              "Hiç ${role == 'driver' ? 'şoför' : 'dispatch'} yok",
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final userDoc = users[i];
            final data = userDoc.data();
            final name = (data['name'] ?? '') as String;
            final email = (data['email'] ?? '') as String;

            return Dismissible(
              key: Key(userDoc.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Emin misiniz?"),
                    content: Text("$name adlı kullanıcı silinecek."),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Vazgeç")),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        child: const Text("Sil"),
                      )
                    ],
                  ),
                );
                return result == true;
              },
              onDismissed: (_) async {
                await _deleteUser(userDoc.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("$name silindi.")),
                );
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.redAccent,
                child: const Icon(Icons.delete, color: Colors.white, size: 28),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: role == 'driver'
                      ? Colors.blue.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    role == 'driver' ? Icons.local_shipping : Icons.support_agent,
                    color: role == 'driver' ? Colors.blue : Colors.orange,
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(email),
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
          const TabBar(
            indicatorColor: Colors.blue,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Şoförler"),
              Tab(text: "Dispatch"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserList(context, 'driver'),
                _buildUserList(context, 'dispatch'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
