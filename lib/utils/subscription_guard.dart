
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/subscription_plan.dart';

class SubscriptionGuard {
  static const String _collection = 'subscriptions';

  /// Check if the user can perform an action (e.g. add a truck)
  /// Returns validation result: { 'allowed': bool, 'reason': String? }
  static Future<Map<String, dynamic>> checkLimit({
    required String uid,
    required String actionType, // e.g. 'add_truck'
    required int currentCount,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_collection)
          .doc(uid)
          .get();

      if (!snapshot.exists) {
        // Default strict: No subscription, no action (or use Free Tier logic)
        // For this demo: Starter plan default logic could be applied here if we had a free tier
         return {'allowed': false, 'reason': 'Abonelik bulunamadı.'};
      }

      final data = snapshot.data();
      if (data == null || data['status'] != 'active') {
         return {'allowed': false, 'reason': 'Aktif abonelik bulunamadı.'};
      }

      // Determine Plan
      final planId = data['planId'] as String?;
      final plan = SubscriptionPlan.plans.firstWhere(
        (p) => p.id == planId,
        orElse: () => SubscriptionPlan.plans[0], // Fallback/Error
      );

      // Check Limit
      if (actionType == 'add_truck') {
        if (currentCount >= plan.truckLimit) {
          return {
            'allowed': false, 
            'reason': 'Plan limitine ulaştınız (${plan.truckLimit}). Yükseltin.'
          };
        }
      }

      return {'allowed': true};
      
    } catch (e) {
      return {'allowed': false, 'reason': 'Hata: $e'};
    }
  }
}
