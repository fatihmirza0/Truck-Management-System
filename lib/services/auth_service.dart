import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart'; // 🔥 YENİ
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import '../config/app_config.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔥 YENİ: Native method channel
  static const _channel = MethodChannel('location_service');

  // SharedPreferences keys
  static const String _keyIsLoggedIn = 'isLoggedIn';
  static const String _keyUserRole = 'userRole';
  static const String _keyUserId = 'userId';
  static const String _keyUserEmail = 'userEmail';
  static const String _keyUserName = 'userName';

  /// Kullanıcı giriş yaptı mı kontrol et
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool(_keyIsLoggedIn) ?? false;

    // Firebase'de session varsa ve prefs'te kayıtlıysa
    return isLogged && _auth.currentUser != null;
  }

  /// Kullanıcı bilgilerini kaydet
  static Future<void> saveUserData({
    required String uid,
    required String email,
    required String name,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserId, uid);
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyUserRole, role);
  }

  /// Kayıtlı kullanıcı rolünü al
  static Future<String?> getSavedUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }

  /// Kayıtlı kullanıcı bilgilerini al
  static Future<Map<String, String?>> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uid': prefs.getString(_keyUserId),
      'email': prefs.getString(_keyUserEmail),
      'name': prefs.getString(_keyUserName),
      'role': prefs.getString(_keyUserRole),
    };
  }

  /// Login işlemi
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Firebase ile giriş yap
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return {'success': false, 'message': 'Kullanıcı bulunamadı'};
      }

      // Firestore'dan kullanıcı bilgilerini al
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _auth.signOut();
        return {'success': false, 'message': 'Kullanıcı verisi bulunamadı'};
      }

      final userData = userDoc.data()!;

      // Aktif mi kontrol et
      if (userData['isActive'] != true || userData['softDeleted'] == true) {
        await _auth.signOut();
        return {'success': false, 'message': 'Hesabınız deaktif edilmiş'};
      }

      // lastLoginAt güncelle
      await _callUpdateLastLoginHttp(user);

      // SharedPreferences'a kaydet
      await saveUserData(
        uid: user.uid,
        email: user.email ?? email,
        name: userData['name'] ?? 'User',
        role: userData['role'] ?? 'user',
      );

      return {
        'success': true,
        'role': userData['role'],
        'uid': user.uid,
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Giriş başarısız';

      switch (e.code) {
        case 'user-not-found':
          message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı';
          break;
        case 'wrong-password':
          message = 'Hatalı şifre';
          break;
        case 'invalid-email':
          message = 'Geçersiz e-posta adresi';
          break;
        case 'user-disabled':
          message = 'Bu hesap devre dışı bırakılmış';
          break;
        case 'too-many-requests':
          message =
          'Çok fazla başarısız deneme. Lütfen daha sonra tekrar deneyin';
          break;
        case 'network-request-failed':
          message = 'İnternet bağlantısı yok';
          break;
        default:
          message = 'E posta veya şifre yanlış';
      }

      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Beklenmeyen hata: $e'};
    }
  }

  /// 🔥 Logout işlemi - TAM TEMİZLİK
  static Future<void> logoutFast() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> logoutCleanup() async {
    try {
      await NotificationService.clearToken();
      await _firestore.collection('users')
          .doc(_auth.currentUser?.uid)
          .update({'fcmToken': FieldValue.delete()});

      await _channel.invokeMethod('logout');
    } catch (e) {
      debugPrint("⚠️ Background cleanup error: $e");
    }
  }

  /// Tüm verileri temizle (debug için)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 🔥 Native temizlik de yap
    try {
      await _channel.invokeMethod('logout');
    } catch (e) {
      debugPrint("⚠️ Native clear error: $e");
    }
  }

  static Future<void> _callUpdateLastLoginHttp(User user) async {
    final token = await user.getIdToken();

    final res = await http.post(
      Uri.parse(AppConfig.updateLastLoginUrl),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("updateLastLoginHttp failed");
    }
  }
}