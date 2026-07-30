// Hanagram — yorum veri modeli

class Review {
  const Review({
    required this.name,
    required this.rating,
    required this.date,
    required this.text,
    this.isVerified = false,
    this.avatarText = '',
    this.id = '',
  });

  final String name;
  final int rating; // 1-5
  final String date;
  final String text;
  final bool isVerified; // randevu sahibi mi
  final String avatarText; // initials, e.g. "AY"
  final String id; // Supabase reviews.id — boşsa (sample veri) silinemez

  factory Review.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? '';
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
    final date = j['date'] as DateTime?;
    return Review(
      id: j['id'] as String? ?? '',
      name: name,
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      date: date != null
          ? '${date.day} ${_monthName(date.month)} ${date.year}'
          : '',
      text: j['text'] as String? ?? '',
      isVerified: j['isVerified'] as bool? ?? false,
      avatarText: initials,
    );
  }

  static String _monthName(int m) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return months[m - 1];
  }
}
