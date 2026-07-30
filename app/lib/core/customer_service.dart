// Hanagram — müşteri dizini servisi (Supabase)
//
// customers tablosu (kişi kartı: ad/telefon/e-posta/not/etiket) +
// crm_entries'ten telefon eşleşmesiyle hesaplanan ziyaret istatistikleri.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CustomerService {
  CustomerService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Müşteri listesini getir (isteğe bağlı arama), ziyaret istatistikleriyle.
  static Future<List<Map<String, dynamic>>> getCustomers({
    String query = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      var customersQuery =
          _db.from('customers').select().eq('owner_id', userId);
      if (query.isNotEmpty) {
        customersQuery =
            customersQuery.or('name.ilike.%$query%,phone.ilike.%$query%');
      }
      final customers =
          await customersQuery.order('created_at', ascending: false);

      final entries = await _db
          .from('crm_entries')
          .select('customer_phone, amount, date')
          .eq('user_id', userId)
          .neq('customer_phone', '');

      final statsByPhone = <String, _VisitStats>{};
      for (final row in (entries as List)) {
        final e = row as Map<String, dynamic>;
        final phone = e['customer_phone'] as String? ?? '';
        if (phone.isEmpty) continue;
        final amount = (e['amount'] as num?)?.toInt() ?? 0;
        final date = DateTime.tryParse(e['date'] as String? ?? '');
        final stats = statsByPhone.putIfAbsent(phone, () => _VisitStats());
        stats.visitCount++;
        stats.totalSpendKurus += amount;
        if (date != null &&
            (stats.lastVisit == null || date.isAfter(stats.lastVisit!))) {
          stats.lastVisit = date;
        }
      }

      return (customers as List).cast<Map<String, dynamic>>().map((c) {
        final phone = c['phone'] as String? ?? '';
        final stats = statsByPhone[phone];
        final tagsData = c['tags'];
        return {
          'id': c['id'],
          'businessId': c['owner_id'],
          'name': c['name'],
          'phone': c['phone'],
          'email': c['email'],
          'note': c['note'],
          'tags': tagsData is List ? tagsData : const [],
          'linkedUserId': c['linked_user_id'],
          'createdAt': DateTime.tryParse(c['created_at'] as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
          'lastVisitAt': stats?.lastVisit?.millisecondsSinceEpoch ?? 0,
          'visitCount': stats?.visitCount ?? 0,
          'totalSpendKurus': stats?.totalSpendKurus ?? 0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Yeni müşteri kartı oluştur. Aynı telefonla ikinci kez eklenmez (DB kısıtı).
  static Future<bool> createCustomer({
    required String name,
    String phone = '',
    String email = '',
    String note = '',
    List<String> tags = const [],
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      await _db.from('customers').insert({
        'owner_id': userId,
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'tags': tags,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mevcut müşteri kartını güncelle.
  static Future<bool> updateCustomer({
    required String customerId,
    required String name,
    String phone = '',
    String email = '',
    String note = '',
    List<String> tags = const [],
  }) async {
    try {
      await _db.from('customers').update({
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'tags': tags,
      }).eq('id', customerId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _VisitStats {
  int visitCount = 0;
  int totalSpendKurus = 0;
  DateTime? lastVisit;
}
