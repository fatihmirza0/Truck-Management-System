import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/widgets/empty_state.dart';

import 'package:lojistik/services/firestore_service.dart';
import '../widgets/active_jobs_header.dart';
import '../widgets/active_job_card.dart';

class ActiveJobsPage extends StatefulWidget {
  final String uid;

  const ActiveJobsPage({super.key, required this.uid});

  @override
  State<ActiveJobsPage> createState() => _ActiveJobsPageState();
}

class _ActiveJobsPageState extends State<ActiveJobsPage> {
  static const Color primary = Color(0xFF1E3A5F);
  static const Color bg = Color(0xFFF8FAFC);
  
  String? _companyId;
  
  @override
  void initState() {
    super.initState();
    _loadCompanyId();
  }
  
  Future<void> _loadCompanyId() async {
    final cid = await FirestoreService.getCompanyId();
    if (mounted) {
      setState(() {
        _companyId = cid;
      });
    }
  }

  Stream<QuerySnapshot> _getActiveJobs() {
    if (_companyId == null) return const Stream.empty();
    
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('companyId', isEqualTo: _companyId) // 🔥 SAAS
        .where('status', isEqualTo: 'approved') // Sadece onaylanmış işler
        .where('driverId', isEqualTo: widget.uid)
        .where('softDeleted', isEqualTo: false)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getActiveJobs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(primary),
                ),
              );
            }

            final jobs = snapshot.data?.docs ?? [];
            if (jobs.isEmpty) {
              return const EmptyState(message: "Aktif iş bulunamadı.");
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ActiveJobsHeader(),
                  const SizedBox(height: 28),
                  ...jobs.map((jobDoc) {
                    final data = jobDoc.data() as Map<String, dynamic>? ?? {};
                    final String vehicleId = (data['vehicleId'] ?? '').toString();
                    final String createdBy = (data['createdBy'] ?? '').toString();

                    return FutureBuilder<Map<String, String?>>(
                      future: _loadJobDetails(vehicleId, createdBy),
                      builder: (context, snap) {
                        String? vehiclePlate;
                        String? dispatchName;
                        String? dispatchPhone;

                        if (snap.hasData) {
                          vehiclePlate = snap.data!['vehiclePlate'];
                          dispatchName = snap.data!['dispatchName'];
                          dispatchPhone = snap.data!['dispatchPhone'];
                        }

                        return ActiveJobCard(
                          job: data,
                          jobId: jobDoc.id,
                          driverId: widget.uid,
                          vehiclePlate: vehiclePlate,
                          dispatchName: dispatchName,
                          dispatchPhone: dispatchPhone,
                        );
                      },
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, String?>> _loadJobDetails(
      String vehicleId, String createdBy) async {
    String? vehiclePlate;
    String? dispatchName;
    String? dispatchPhone;

    if (vehicleId.isNotEmpty) {
      try {
        final vehicleDoc = await FirebaseFirestore.instance
            .collection('vehicles')
            .doc(vehicleId)
            .get();
        if (vehicleDoc.exists) {
          final v = vehicleDoc.data();
          vehiclePlate = (v?['plate'] ?? '-').toString();
        }
      } catch (e) {
        vehiclePlate = "Bulunamadı";
      }
    }

    if (createdBy.isNotEmpty) {
      try {
        final dispatchDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(createdBy)
            .get();
        if (dispatchDoc.exists) {
          final dispatch = dispatchDoc.data();
          dispatchName = (dispatch?['name'] ?? '-').toString();
          dispatchPhone = (dispatch?['phone'] ?? '-').toString();
        }
      } catch (e) {
        dispatchName = "Bulunamadı";
      }
    }

    return {
      'vehiclePlate': vehiclePlate,
      'dispatchName': dispatchName,
      'dispatchPhone': dispatchPhone,
    };
  }
}

