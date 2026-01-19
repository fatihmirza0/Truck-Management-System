import 'package:flutter/material.dart';
import '../../models/subscription_plan.dart';

class PricingCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool isAnnual;
  final String currencySymbol;
  final VoidCallback onSelect;
  final bool isLoading;

  const PricingCard({
    super.key,
    required this.plan,
    required this.isAnnual,
    required this.currencySymbol,
    required this.onSelect,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Simple color scheme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    // Highlight popular plan
    final borderColor = plan.isPopular ? Colors.indigoAccent : (isDark ? Colors.white10 : Colors.black12);
    final borderWidth = plan.isPopular ? 2.0 : 1.0;

    double price = currencySymbol == '₺' ? plan.priceTry : plan.priceUsd;
    
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (plan.isPopular)
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          else 
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plan.isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.indigoAccent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'En Popüler',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            plan.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                '/ay',
                style: TextStyle(
                  fontSize: 16,
                  color: textColor.withOpacity(0.5),
                  height: 2, // Align with bottom
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.indigoAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(color: textColor.withOpacity(0.8)),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: plan.isPopular ? Colors.indigoAccent : Colors.transparent,
                foregroundColor: plan.isPopular ? Colors.white : Colors.indigoAccent,
                elevation: plan.isPopular ? 2 : 0,
                side: plan.isPopular ? BorderSide.none : const BorderSide(color: Colors.indigoAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(plan.isPopular ? 'Hemen Başla' : 'Seç'),
            ),
          ),
        ],
      ),
    );
  }
}
