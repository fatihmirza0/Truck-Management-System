import 'dart:convert';

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
      // 🔔 Permission
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 🔔 Local notifications init
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

      // 🔥 TOKEN → CLOUD FUNCTION
      await _sendTokenToBackend();

      // 🔄 Token refresh
      _fcm.onTokenRefresh.listen((token) async {
        await _sendTokenToBackend(token: token);
      });

      // 📬 Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 📬 Background tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } catch (e) {
      debugPrint("🔕 NotificationService init skipped: $e");
    }
  }

  // ===============================
  // SEND TOKEN (NO FIRESTORE!)
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
          "https://us-central1-PROJECT_ID.cloudfunctions.net/saveFcmTokenHttp",
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
  static Future<void> _handleForegroundMessage(
      RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'job_channel',
      'İş Bildirimleri',
      channelDescription: 'Yeni iş atamaları',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Yeni Bildirim',
      message.notification?.body ?? '',
      details,
      payload: message.data['jobId'],
    );
  }

  // ===============================
  // NOTIFICATION TAP
  // ===============================
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint("🔔 Notification tapped: ${response.payload}");
    // TODO: job detail navigation
  }

  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint("🔔 Background notification tapped");
    // TODO: job detail navigation
  }

  // ===============================
  // LOGOUT
  // ===============================
  static Future<void> clearToken() async {
    await _fcm.deleteToken();
  }

}
