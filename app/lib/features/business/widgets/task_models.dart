// Hanagram — görev yönetimi yardımcı modelleri

/// Çalışan verisi.
class Worker {
  const Worker({
    required this.name,
    required this.role,
    required this.status,
    required this.avatar,
  });

  final String name;
  final String role;
  final String status; // Aktif, Beklemede
  final String avatar;

  static final sampleWorkers = [
    Worker(name: 'Ayşe Yılmaz', role: 'Kuaför', status: 'Aktif', avatar: 'AY'),
    Worker(name: 'Mehmet Kaya', role: 'Manikürcü', status: 'Aktif', avatar: 'MK'),
    Worker(name: 'Zeynep Demir', role: 'Makyöz', status: 'Beklemede', avatar: 'ZD'),
  ];
}
