import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  PaymentService._internal();

  // Explicitly set the region to us-central1 for Gen 2 functions
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Check if platform supports Cloud Functions
  bool get _isPlatformSupported {
    if (kIsWeb) return true;
    try {
      if (Platform.isAndroid || Platform.isIOS) return true;
    } catch (_) {}
    return false;
  }

  /// Initiate checkout for a specific plan
  Future<String> initiateCheckout({
    required String planId,
    required String countryCode,
  }) async {
    try {
      if (!_isPlatformSupported) {
        throw Exception('Bu özellik şu an seçtiğiniz platformda desteklenmiyor. Lütfen Web veya Mobil uygulama üzerinden deneyiniz.');
      }

      final result = await _functions.httpsCallable('createSubscription').call({
        'planId': planId,
        'country': countryCode,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final checkoutUrl = data['checkoutUrl'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('Ödeme sayfası oluşturulamadı.');
      }

      return checkoutUrl;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Functions Error: ${e.code} - ${e.message}');
      throw Exception('Ödeme servisi hatası: ${e.message}');
    } catch (e) {
      debugPrint('Checkout Error: $e');
      rethrow;
    }
  }
}
