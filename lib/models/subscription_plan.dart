
enum SubscriptionStatus {
  active,
  pastDue,
  canceled,
  unpaid,
  none,
}

class SubscriptionPlan {
  final String id;
  final String name;
  final double priceTry;
  final double priceUsd;
  final int truckLimit;
  final List<String> features;
  final bool isPopular;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceTry,
    required this.priceUsd,
    required this.truckLimit,
    required this.features,
    this.isPopular = false,
  });

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: 'starter',
      name: 'Starter',
      priceTry: 45000,
      priceUsd: 1200,
      truckLimit: 20,
      features: [
        '20 Kamyon Limiti',
        'Temel Raporlama',
        '7/24 Destek',
      ],
    ),
    SubscriptionPlan(
      id: 'professional',
      name: 'Professional',
      priceTry: 95000,
      priceUsd: 2500,
      truckLimit: 999999, // Unlimited
      features: [
        'Sınırsız Kamyon',
        'Gelişmiş GPS Takibi',
        'Detaylı Analitik',
        'Öncelikli Destek',
      ],
      isPopular: true,
    ),
    SubscriptionPlan(
      id: 'enterprise',
      name: 'Enterprise',
      priceTry: 150000,
      priceUsd: 4000,
      truckLimit: 999999, // Unlimited
      features: [
        'Tüm Professional Özellikleri',
        'Yapay Zeka Modülleri',
        'Özel Entegrasyonlar',
        'Dedicated Account Manager',
      ],
    ),
  ];
}
