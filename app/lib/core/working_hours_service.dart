// Hanagram — İşletme çalışma saatleri (working_hours) okuma/yazma katmanı.
// Supabase tablosundaki satırları model'e dönüştürür ve CRUD işlemleri sunar.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// Veritabanı `working_hours` satırını temsil eder.
class WorkingHours {
  final String id;
  final String businessId;
  final int weekday; // DB biçimi: 0=Pazar … 6=Cumartesi
  final String openTime; // "HH:mm"
  final String closeTime; // "HH:mm"
  final bool isClosed;

  const WorkingHours({
    required this.id,
    required this.businessId,
    required this.weekday,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  /// Veritabanından gelen JSON'u modele dönüştürür.
  ///
  /// `open_time` / `close_time` "HH:mm:ss" gibi uzun gelebilir; ilk 5
  /// karakter ("HH:mm") olarak kırpılır. Kısa gelirse olduğu gibi alınır.
  factory WorkingHours.fromJson(Map<String, dynamic> j) {
    return WorkingHours(
      id: j['id'] as String? ?? '',
      businessId: j['business_id'] as String? ?? '',
      weekday: (j['weekday'] as num?)?.toInt() ?? 0,
      openTime: _truncateTime(j['open_time'] as String?),
      closeTime: _truncateTime(j['close_time'] as String?),
      isClosed: j['is_closed'] as bool? ?? false,
    );
  }

  /// DB weekday değerine göre Türkçe gün adı.
  String get dayName {
    const names = <String>[
      'Pazar', // 0
      'Pazartesi', // 1
      'Salı', // 2
      'Çarşamba', // 3
      'Perşembe', // 4
      'Cuma', // 5
      'Cumartesi', // 6
    ];
    if (weekday < 0 || weekday >= names.length) return '';
    return names[weekday];
  }

  /// "HH:mm:ss" → "HH:mm"; kısa veya boşsa olduğu gibi döner.
  static String _truncateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '00:00';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }
}

// ---------------------------------------------------------------------------
// Servis
// ---------------------------------------------------------------------------

/// `working_hours` tablosu için CRUD işlemleri.
class WorkingHoursService {
  WorkingHoursService._();

  static SupabaseClient get _db => SupabaseService.client;

  // -- Gün dönüşüm yardımcıları ------------------------------------------------

  /// Dart `DateTime.weekday` (1=Pzt … 7=Paz) → DB biçimi (0=Paz … 6=Cmt).
  static int dartWeekdayToDb(int dartWeekday) =>
      dartWeekday == DateTime.sunday ? 0 : dartWeekday;

  /// DB biçimi (0=Paz … 6=Cmt) → Dart `DateTime.weekday` (1=Pzt … 7=Paz).
  static int dbWeekdayToDart(int dbWeekday) =>
      dbWeekday == 0 ? DateTime.sunday : dbWeekday;

  // -- Okuma ------------------------------------------------------------------

  /// Belirli bir işletmenin haftalık çalışma saatlerini weekday ARTAN
  /// sırayla döndürür. Randevu akışında (başkasının profili) kullanılır.
  static Future<List<WorkingHours>> getForBusiness(String businessId) async {
    try {
      final result = await _db
          .from('working_hours')
          .select('*')
          .eq('business_id', businessId)
          .order('weekday', ascending: true);
      return (result as List)
          .map((j) => WorkingHours.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Oturumdaki kullanıcının kendi çalışma saatlerini döndürür.
  static Future<List<WorkingHours>> getMine() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];
      final result = await _db
          .from('working_hours')
          .select('*')
          .eq('business_id', userId)
          .order('weekday', ascending: true);
      return (result as List)
          .map((j) => WorkingHours.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Verilen tarihin haftanın gününe denk gelen çalışma saatini döndürür.
  ///
  /// Kayıt yoksa `null` döner — çağıran taraf "saat belirlenmemiş"
  /// durumunu kendi yönetir, burada varsayılan saat ÜRETİLMEZ.
  static Future<WorkingHours?> getForDate(
    String businessId,
    DateTime date,
  ) async {
    try {
      final dbWeekday = dartWeekdayToDb(date.weekday);
      final result = await _db
          .from('working_hours')
          .select('*')
          .eq('business_id', businessId)
          .eq('weekday', dbWeekday)
          .maybeSingle();
      if (result == null) return null;
      return WorkingHours.fromJson(result);
    } catch (_) {
      return null;
    }
  }

  // -- Yazma ------------------------------------------------------------------

  /// Belirli bir günün çalışma saatini Upsert eder.
  ///
  /// Aynı `(business_id,衛 weekday)` çifti varsa günceller, yoksa ekler.
  /// Oturum yoksa `false` döner.
  static Future<bool> setDay({
    required int weekday,
    required String openTime,
    required String closeTime,
    required bool isClosed,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      await _db.from('working_hours').upsert(
            {
              'business_id': userId,
              'weekday': weekday,
              'open_time': openTime,
              'close_time': closeTime,
              'is_closed': isClosed,
            },
            onConflict: 'business_id,weekday',
          );
      return true;
    } catch (_) {
      return false;
    }
  }
}