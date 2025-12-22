import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class JobService {
  static final _firestore = FirebaseFirestore.instance;
  static const _baseUrl = 'https://us-central1-truck-dispatch-system.cloudfunctions.net';

  static Future<void> approveJob(String jobId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not authenticated");

    try {
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/jobAction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jobId': jobId,
          'action': 'approve',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Job onaylanamadı: $e');
    }
  }

  static Future<void> rejectJob(String jobId, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not authenticated");

    try {
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/jobAction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jobId': jobId,
          'action': 'reject',
          'reason': reason,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Job reddedilemedi: $e');
    }
  }

  static Future<void> completeJob(String jobId, {String? deliveryProofUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Not authenticated");

    try {
      if (deliveryProofUrl != null) {
        await _firestore.collection("jobs").doc(jobId).update({
          "deliveryProof": deliveryProofUrl,
        });
      }

      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse('$_baseUrl/jobAction'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'jobId': jobId,
          'action': 'complete',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Job tamamlanamadı: $e');
    }
  }

  static Future<void> deleteJob(String jobId) async {
    await _firestore.collection("jobs").doc(jobId).update({
      "softDeleted": true,
    });
  }

  static Future<Map<String, dynamic>?> getJobDetails(String jobId) async {
    final doc = await _firestore.collection("jobs").doc(jobId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  static Stream<QuerySnapshot> getJobLogs(String jobId) {
    return _firestore
        .collection("jobs")
        .doc(jobId)
        .collection("logs")
        .orderBy("performedAt", descending: true)
        .snapshots();
  }
}