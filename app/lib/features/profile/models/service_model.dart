// Hanagram — hizmet/kategori veri modeli

class ServiceCategory {
  const ServiceCategory({
    required this.name,
    required this.services,
    required this.gradientColors,
  });

  final String name;
  final List<ServiceItem> services;
  final List<int> gradientColors; // [0xFF..., 0xFF...]

  static const sampleCategories = [
    ServiceCategory(
      name: 'Lazer Epilasyon',
      gradientColors: [0xFF8B36E0, 0xFFA855F7],
      services: [
        ServiceItem(name: 'Tam Vücut', price: '₺8,000', description: '6 seans'),
        ServiceItem(name: 'Yüz', price: '₺3,000', description: '4 seans'),
        ServiceItem(name: 'Bikini', price: '₺4,000', description: '4 seans'),
      ],
    ),
    ServiceCategory(
      name: 'Cilt Bakımı',
      gradientColors: [0xFF3A5FE0, 0xFF5B7CFA],
      services: [
        ServiceItem(name: 'Hydrafacial', price: '₺2,500', description: 'Tek seans'),
        ServiceItem(name: 'Mezoterapi', price: '₺3,500', description: '4 seans'),
        ServiceItem(name: 'PRP', price: '₺4,000', description: '3 seans'),
      ],
    ),
    ServiceCategory(
      name: 'Saç Bakımı',
      gradientColors: [0xFF10A46A, 0xFF3DD68C],
      services: [
        ServiceItem(name: 'Saç Botoksu', price: '₺2,000', description: 'Tek seans'),
        ServiceItem(
          name: 'Saç Ekimi Danışmanlığı',
          price: 'Ücretsiz',
          description: 'Randevu ile',
        ),
      ],
    ),
  ];
}

class ServiceItem {
  const ServiceItem({
    required this.name,
    required this.price,
    required this.description,
  });

  final String name;
  final String price;
  final String description;
}
