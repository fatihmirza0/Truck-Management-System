import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class DriverScreen extends StatelessWidget {
  final String driverId;

  const DriverScreen({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Şoför Paneli")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getAllApprovedJobs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔹 Onaylanmış tüm işleri çekip sadece bu şoföre ait olanları filtrele
          final allJobs = snapshot.data!.docs;
          final myJobs = allJobs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['assignedTo'] == driverId;
          }).toList();

          if (myJobs.isEmpty) {
            return const Center(child: Text("Atanmış iş bulunamadı"));
          }

          return ListView.builder(
            itemCount: myJobs.length,
            itemBuilder: (context, index) {
              final job = myJobs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Yük: ${job['cargoInfo']}"),
                  subtitle: Text("${job['loadPort']} → ${job['unloadPort']}"),
                  trailing: Text(
                    job['status'].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
