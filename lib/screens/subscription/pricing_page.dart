import 'package:flutter/material.dart';
import '../../models/subscription_plan.dart';
import '../../widgets/subscription/pricing_card.dart';
import '../../services/payment_service.dart';
import '../../widgets/subscription/legal_consent_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'payment_webview.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});

  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isTurkey = true; // Default to Turkey
  bool _isLoading = false;
  final _paymentService = PaymentService();
  bool _consentGiven = false;

  void _handlePlanSelect(SubscriptionPlan plan) async {
    if (_isTurkey && !_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen sözleşmeleri onaylayınız.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // ... existing logic
    try {
      final countryCode = _isTurkey ? 'TR' : 'US';
      final url = await _paymentService.initiateCheckout(
        planId: plan.id,
        countryCode: countryCode,
      );
      
      if (mounted) {
        if (kIsWeb) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Ödeme sayfası açılamadı.');
          }
        } else {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (context) => PaymentWebView(initialUrl: url),
            ),
          );

          if (mounted) {
            if (result == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ödeme başarıyla tamamlandı!')),
              );
            } else if (result == false) {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ödeme başarısız oldu.')),
              );
            } else {
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ödeme iptal edildi.')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = _isTurkey ? '₺' : '\$';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        // ... existing app bar
        title: const Text('Abonelik Planları'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Country Toggle
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CountryTab(
                    label: 'Global (USD)',
                    isSelected: !_isTurkey,
                    onTap: () => setState(() { 
                      _isTurkey = false;
                      _consentGiven = true; // Not required for global in this flow (simplified)
                    }),
                  ),
                  _CountryTab(
                    label: 'Türkiye (TRY)',
                    isSelected: _isTurkey,
                    onTap: () => setState(() {
                      _isTurkey = true;
                      _consentGiven = false; // Reset consent
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
            children: [
                if (_isTurkey) ...[
                    Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                            child: SizedBox(
                                width: 600,
                                child: LegalConsentWidget(
                                    onConsentChanged: (val) => setState(() => _consentGiven = val),
                                ),
                            ),
                        ),
                    ),
                ],
                Center(
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: SubscriptionPlan.plans.map((plan) {
                      return PricingCard(
                        plan: plan,
                        isAnnual: false, // Monthly only for now
                        currencySymbol: currencySymbol,
                        isLoading: _isLoading,
                        onSelect: () => _handlePlanSelect(plan),
                      );
                    }).toList(),
                  ),
                ),
            ],
        ),
      ),
    );
  }
}

class _CountryTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
