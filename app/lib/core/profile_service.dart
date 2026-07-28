// Hanagram — profil servisi (Supabase)
//
// Profil istatistikleri, rozet hesaplama, display tercihi, konum bilgisi.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Profil istatistik modeli.
class ProfileStatsData {
  const ProfileStatsData({
    this.displayStat = 'appointments',
    this.appointmentCount = 0,
    this.salesCount = 0,
    this.totalCustomers = 0,
    this.avgResponseMinutes = -1,
    this.address = '',
    this.latitude,
    this.longitude,
    this.phone = '',
  });

  final String displayStat;
  final int appointmentCount;
  final int salesCount;
  final int totalCustomers;
  final int avgResponseMinutes;
  final String address;
  final double? latitude;
  final double? longitude;
  final String phone;

  /// Kullanıcının seçtiği türdeki toplam sayı.
  int get primaryCount =>
      displayStat == 'sales' ? salesCount : appointmentCount;

  /// Kullanıcının seçtiği tür etiketi.
  String get primaryLabel =>
      displayStat == 'sales' ? 'Satış' : 'Randevu';

  /// Hızlı yanıt rozeti aktif mi (1 saatten kısa).
  bool get isFastResponder =>
      avgResponseMinutes > 0 && avgResponseMinutes < 60;

  /// Rozet mesajı.
  String get fastResponderMessage =>
      'Hızlı Yanıt ⚡ Ortalama $avgResponseMinutes dk';
}

class ProfileService {
  ProfileService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Kullanıcının profil istatistiklerini getir.
  static Future<ProfileStatsData> getProfileStats(
      String targetAuthId) async {
    try {
      // 1. Kullanıcı bilgileri
      final userResult = await _db
          .from('users')
          .select(
              'display_stat, avg_response_minutes, address, latitude, longitude, phone')
          .eq('auth_id', targetAuthId)
          .maybeSingle();

      if (userResult == null) return const ProfileStatsData();

      final displayStat =
          userResult['display_stat'] as String? ?? 'appointments';
      final avgResponse =
          userResult['avg_response_minutes'] as int? ?? -1;
      final address = userResult['address'] as String? ?? '';
      final lat = userResult['latitude'] as double?;
      final lng = userResult['longitude'] as double?;
      final phone = userResult['phone'] as String? ?? '';

      // 2. Kullanıcının auth_id'sinden users tablosundaki id'yi bul
      final userRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', targetAuthId)
          .maybeSingle();
      final userId = userRow?['id'] as String?;

      if (userId == null) {
        return ProfileStatsData(
          displayStat: displayStat,
          avgResponseMinutes: avgResponse,
          address: address,
          latitude: lat,
          longitude: lng,
          phone: phone,
        );
      }

      // 3. Paralel sorgular: randevular, CRM, satışlar
      final results = await Future.wait([
        // Randevu sayısı
        _db
            .from('appointments')
            .select('id')
            .or('created_by.eq.$userId,attendee_id.eq.$userId'),
        // CRM müşteri sayısı (benzersiz müşteri adları)
        _db
            .from('crm_entries')
            .select('customer_name')
            .eq('user_id', userId),
        // Satış tutarı (CRM'deki satış tipindekiler)
        _db
            .from('crm_entries')
            .select('amount')
            .eq('user_id', userId)
            .eq('type', 'sale'),
      ]);

      final apptCount = (results[0] as List).length;

      // Benzersiz müşteri sayısını hesapla
      final crmRows = results[1] as List;
      final uniqueCustomers = <String>{};
      for (final row in crmRows) {
        final name = (row as Map)['customer_name'] as String? ?? '';
        if (name.isNotEmpty) uniqueCustomers.add(name.toLowerCase());
      }

      // Satış sayısını hesapla
      final saleRows = results[2] as List;
      final totalSales =
          saleRows.fold<int>(0, (sum, r) => sum + (r as Map)['amount'] as int? ?? 0);

      return ProfileStatsData(
        displayStat: displayStat,
        appointmentCount: apptCount,
        salesCount: totalSales,
        totalCustomers: uniqueCustomers.length,
        avgResponseMinutes: avgResponse,
        address: address,
        latitude: lat,
        longitude: lng,
        phone: phone,
      );
    } catch (_) {
      return const ProfileStatsData();
    }
  }

  /// Display tercihini güncelle (randevu veya satış gösterilsin).
  static Future<bool> setDisplayStat(String statType) async {
    try {
      await _db.from('users').update({
        'display_stat': statType,
      }).eq('auth_id', SupabaseService.user?.id ?? '');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Profil adresini güncelle.
  static Future<bool> updateAddress({
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return false;

      await _db.from('users').update({
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      }).eq('auth_id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
