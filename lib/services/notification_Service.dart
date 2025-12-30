import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // ===============================
  // INIT
  // ===============================
  static Future<void> initialize() async {
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _sendTokenToBackend();

      _fcm.onTokenRefresh.listen((token) async {
        await _sendTokenToBackend(token: token);
      });

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } catch (e) {
      debugPrint("🔕 NotificationService init skipped: $e");
    }
  }

  // ===============================
  // SEND TOKEN
  // ===============================
  static Future<void> _sendTokenToBackend({String? token}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null) return;

      final idToken = await user.getIdToken();

      final res = await http.post(
        Uri.parse(
          "https://us-central1-truck-dispatch-system.cloudfunctions.net/saveFcmTokenHttp",
        ),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "token": fcmToken,
        }),
      );

      if (res.statusCode != 200) {
        throw Exception("saveFcmTokenHttp failed");
      }

      debugPrint("✅ FCM token sent via HTTP");
    } catch (e) {
      debugPrint("❌ saveFcmTokenHttp error: $e");
    }
  }

  // ===============================
  // FOREGROUND MESSAGE
  // ===============================
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notificationType = message.data['type'] ?? '';

    String channelId = 'default_channel';
    String channelName = 'Genel Bildirimler';
    String channelDesc = 'Genel bildirimler';

    switch (notificationType) {
      case 'new_job':
        channelId = 'new_job_channel';
        channelName = 'Yeni İş Bildirimleri';
        channelDesc = 'Yeni iş atamaları için bildirimler';
        break;
      case 'job_approved':
        channelId = 'job_approved_channel';
        channelName = 'İş Onay Bildirimleri';
        channelDesc = 'İş onaylandığında gelen bildirimler';
        break;
      case 'new_job_assigned':
        channelId = 'job_assigned_channel';
        channelName = 'İş Atama Bildirimleri';
        channelDesc = 'Size iş atandığında gelen bildirimler';
        break;
      case 'job_completed':
      case 'job_completed_dispatch':
        channelId = 'job_completed_channel';
        channelName = 'İş Tamamlama Bildirimleri';
        channelDesc = 'İş tamamlandığında gelen bildirimler';
        break;
      case 'driver_offline':
        channelId = 'driver_offline_channel';
        channelName = 'Sürücü Çevrimdışı';
        channelDesc = 'Sürücü bağlantısı kesildi';
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Yeni Bildirim',
      message.notification?.body ?? '',
      details,
      payload: jsonEncode({
        'jobId': message.data['jobId'],
        'driverId': message.data['driverId'],
        'type': message.data['type'],
      }),
    );
  }

  // ===============================
  // NOTIFICATION TAP
  // ===============================
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        final jobId = data['jobId'];
        final driverId = data['driverId'];
        final type = data['type'];

        debugPrint("🔔 Notification tapped - Type: $type");

        _navigateBasedOnUserRole(jobId, driverId, type);
      } catch (e) {
        debugPrint("❌ Payload parse error: $e");
      }
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final jobId = message.data['jobId'];
    final driverId = message.data['driverId'];
    final type = message.data['type'];

    debugPrint("🔔 Background notification tapped - Type: $type");

    _navigateBasedOnUserRole(jobId, driverId, type);
  }

  // ===============================
  // ROLE-BASED NAVIGATION
  // ===============================
  static void _navigateBasedOnUserRole(
      String? jobId, String? driverId, String? type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final role = userDoc.data()?['role'] as String?;

      // ✅ Driver Offline bildirimi için özel yönlendirme
      if (type == 'driver_offline') {
        debugPrint("🚨 DRIVER OFFLINE - Navigate to Live Tracking");
        // Get.toNamed('/manager/live-tracking', arguments: {'driverId': driverId});
        return;
      }

      if (jobId == null) return;

      switch (role) {
        case 'driver':
        // Get.toNamed('/driver/job-detail', arguments: {'jobId': jobId});
          debugPrint("🚛 Navigate to Driver Job Detail: $jobId");
          break;

        case 'manager':
        // Get.toNamed('/manager/job-detail', arguments: {'jobId': jobId});
          debugPrint("👔 Navigate to Manager Job Detail: $jobId");
          break;

        case 'dispatch':
        // Get.toNamed('/dispatch/job-detail', arguments: {'jobId': jobId});
          debugPrint("📋 Navigate to Dispatch Job Detail: $jobId");
          break;

        case 'admin':
        // Get.toNamed('/admin/job-detail', arguments: {'jobId': jobId});
          debugPrint("⚙️ Navigate to Admin Job Detail: $jobId");
          break;

        default:
          debugPrint("❓ Unknown role: $role");
      }
    } catch (e) {
      debugPrint("❌ Navigation error: $e");
    }
  }

  // ===============================
  // LOGOUT
  // ===============================
  static Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();

        await http.post(
          Uri.parse(
            "https://us-central1-truck-dispatch-system.cloudfunctions.net/clearFcmTokenHttp",
          ),
          headers: {
            "Authorization": "Bearer $idToken",
            "Content-Type": "application/json",
          },
        );
      }

      await _fcm.deleteToken();
      debugPrint("✅ FCM token cleared");
    } catch (e) {
      debugPrint("❌ Clear token error: $e");
    }
  }
}