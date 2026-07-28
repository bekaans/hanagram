// Hanagram — merkezi yardımcı fonksiyonlar
//
// Tüm ekranlarda kullanılan formatlama ve dönüşüm fonksiyonları burada tanımlıdır.
// Hiçbir dosya kendi局部 _fmtCount/_relativeTime/_formatCurrency tanımını yapmaz.

/// Sayı formatı: 999 → "999", 1247 → "1.2K", 1000000 → "1M"
String fmtCount(int n) {
  if (n >= 1000000) {
    final m = n / 1000000;
    return m == m.roundToDouble() ? '${m.round()}M' : '${m.toStringAsFixed(1)}M';
  }
  if (n >= 1000) {
    final k = n / 1000;
    return k == k.roundToDouble() ? '${k.round()}K' : '${k.toStringAsFixed(1)}K';
  }
  return '$n';
}

/// İnsani zaman farkı: milisaniye cinsinden iki zaman arasındaki farkı string'e çevirir.
/// [millis] geçerli zaman damgası, [now] referans zamanı (milisaniye).
String relativeTime(int millis, int now) {
  if (millis <= 0) return '';
  final diff = now - millis;
  if (diff < 0) return '';
  final min = diff ~/ 60000;
  if (min < 1) return 'az önce';
  if (min < 60) return '$min dk';
  final hour = min ~/ 60;
  if (hour < 24) return '$hour saat';
  final day = hour ~/ 24;
  if (day < 7) return '$day gün';
  if (day < 30) return '${day ~/ 7} hafta';
  return '${day ~/ 30} ay';
}

/// Para formatı: kuruş cinsinden tam sayıyı TL formatına çevirir.
/// 150000 → "₺1.500,00", 250 → "₺2,50"
String formatCurrency(int kurus) {
  final tl = kurus ~/ 100;
  final kr = kurus % 100;
  final tlStr = tl.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return '₺$tlStr,${kr.toString().padLeft(2, '0')}';
}

/// Tarih formatı: DateTime → "15 Tem 2026"
String formatDate(DateTime d) {
  const aylar = [
    '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
  ];
  return '${d.day} ${aylar[d.month]} ${d.year}';
}

/// Milisaniyeden saat:dakika formatı: 1234567890 → "14:30"
String formatTimeFromMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Milisaniyeden tam tarih+saat: 1234567890 → "15 Tem 2026, 14:30"
String formatDateTimeFromMs(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${formatDate(dt)}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Milisaniyeden tarih: 1234567890 → "15 Tem 2026"
String formatDateFromMs(int ms) {
  return formatDate(DateTime.fromMillisecondsSinceEpoch(ms));
}
