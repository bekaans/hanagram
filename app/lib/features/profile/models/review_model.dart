// Hanagram — yorum veri modeli

class Review {
  const Review({
    required this.name,
    required this.rating,
    required this.date,
    required this.text,
    this.isVerified = false,
    this.avatarText = '',
  });

  final String name;
  final int rating; // 1-5
  final String date;
  final String text;
  final bool isVerified; // randevu sahibi mi
  final String avatarText; // initials, e.g. "AY"

  static const sampleReviews = [
    Review(
      name: 'Ayşe Yılmaz',
      rating: 5,
      date: '20 Tem 2026',
      text: 'Harika bir deneyim! Çok profesyonel ekip.',
      isVerified: true,
      avatarText: 'AY',
    ),
    Review(
      name: 'Mehmet Kaya',
      rating: 4,
      date: '18 Tem 2026',
      text: 'Memnun kaldım, tavsiye ederim.',
      isVerified: true,
      avatarText: 'MK',
    ),
    Review(
      name: 'Zeynep Demir',
      rating: 5,
      date: '15 Tem 2026',
      text: 'En iyi güzellik merkezi!',
      isVerified: true,
      avatarText: 'ZD',
    ),
    Review(
      name: 'Can Yıldız',
      rating: 4,
      date: '10 Tem 2026',
      text: 'Güzel bir ortam, kaliteli hizmet.',
      isVerified: true,
      avatarText: 'CY',
    ),
    Review(
      name: 'Selin Kaya',
      rating: 5,
      date: '5 Tem 2026',
      text: 'Kesinlikle tekrar geleceğim.',
      isVerified: false,
      avatarText: 'SK',
    ),
  ];

  static double get averageRating {
    if (sampleReviews.isEmpty) return 0;
    final total = sampleReviews.fold<int>(0, (sum, r) => sum + r.rating);
    return total / sampleReviews.length;
  }
}
