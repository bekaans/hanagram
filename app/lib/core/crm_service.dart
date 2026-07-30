// Hanagram — CRM servisi
//
// Tek sorumluluk: satış ve randevu kayıtlarını CRM tablosuna ekleme/listeleme.
// Her satış veya randevu otomatik olarak CRM kaydı oluşturur.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// CRM kayıt türleri.
enum CrmType { sale, appointment }

/// CRM kaydı modeli.
class CrmEntry {
  const CrmEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    this.customerName = '',
    this.customerPhone = '',
    this.notes = '',
    this.status = 'completed',
  });

  final String id;
  final CrmType type;
  final String title;
  final int amount; // kuruş cinsinden
  final DateTime date;
  final String customerName;
  final String customerPhone;
  final String notes;
  final String status;

  factory CrmEntry.fromJson(Map<String, dynamic> j) => CrmEntry(
        id: j['id'] as String? ?? '',
        type: j['type'] == 'appointment' ? CrmType.appointment : CrmType.sale,
        title: j['title'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        customerName: j['customer_name'] as String? ?? '',
        customerPhone: j['customer_phone'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        status: j['status'] as String? ?? 'completed',
      );
}

class CrmService {
  CrmService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Yeni CRM kaydı oluştur (satış veya randevu).
  static Future<String?> addEntry({
    required CrmType type,
    required String title,
    required int amount,
    String customerName = '',
    String customerPhone = '',
    String notes = '',
    String status = 'completed',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      final result = await _db.from('crm_entries').insert({
        'user_id': userId,
        'type': type == CrmType.sale ? 'sale' : 'appointment',
        'title': title,
        'amount': amount,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'notes': notes,
        'status': status,
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcının CRM kayıtlarını getir (tarih sırasıyla).
  static Future<List<CrmEntry>> getEntries({
    CrmType? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      var query = _db
          .from('crm_entries')
          .select()
          .eq('user_id', userId);

      if (type != null) {
        final typeStr = type == CrmType.sale ? 'sale' : 'appointment';
        query = query.eq('type', typeStr);
      }

      final result = await query
          .order('date', ascending: false)
          .range(offset, offset + limit - 1);
      return (result as List).map((j) => CrmEntry.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Müşteri adına göre CRM kayıtlarını getir (randevu ekranında arama için).
  static Future<List<CrmEntry>> getEntriesByCustomer(String customerName) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('crm_entries')
          .select()
          .eq('user_id', userId)
          .ilike('customer_name', '%$customerName%')
          .order('date', ascending: false)
          .limit(20);

      return (result as List).map((j) => CrmEntry.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Son satış yapılan kişileri getir (otomatik tamamlama için).
  static Future<List<Map<String, dynamic>>> recentCustomers({int limit = 10}) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('crm_entries')
          .select('customer_name, customer_phone, date, amount')
          .eq('user_id', userId)
          .not('customer_name', 'eq', '')
          .order('date', ascending: false)
          .limit(limit);

      // Tekilleştir (aynı isimden tekrar eklemesin)
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final row in result as List) {
        final map = row as Map<String, dynamic>;
        final name = map['customer_name'] as String? ?? '';
        if (name.isNotEmpty && seen.add(name.toLowerCase())) {
          unique.add(map);
        }
      }
      return unique;
    } catch (_) {
      return [];
    }
  }

  /// Belirli bir müşterinin tüm geçmişini getir (satış + randevu).
  static Future<Map<String, dynamic>> getCustomerHistory(String customerName) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return {'entries': <CrmEntry>[], 'totalSpent': 0, 'visitCount': 0};

      final result = await _db
          .from('crm_entries')
          .select()
          .eq('user_id', userId)
          .ilike('customer_name', '%$customerName%')
          .order('date', ascending: false);

      final entries = (result as List).map((j) => CrmEntry.fromJson(j)).toList();
      final totalSpent = entries.fold<int>(0, (sum, e) => sum + e.amount);
      final visitCount = entries.length;

      return {
        'entries': entries,
        'totalSpent': totalSpent,
        'visitCount': visitCount,
      };
    } catch (_) {
      return {'entries': <CrmEntry>[], 'totalSpent': 0, 'visitCount': 0};
    }
  }

  /// CRM toplam cirosunu getir (belirli tarih aralığında).
  static Future<int> totalRevenue({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return 0;

      var query = _db
          .from('crm_entries')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'sale')
          .eq('status', 'completed');

      if (from != null) {
        query = query.gte('date', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('date', to.toIso8601String());
      }

      final result = await query;
      return (result as List).fold<int>(
        0,
        (sum, j) => sum + ((j['amount'] as num?)?.toInt() ?? 0),
      );
    } catch (_) {
      return 0;
    }
  }

  // ─── SATIŞLAR (sale_screen.dart) ───

  /// Yeni satış kaydet — ürün kalemleriyle (`type='sale'` crm_entries kaydı).
  static Future<String?> createSale({
    required List<Map<String, dynamic>> items,
    String customerName = '',
    String customerPhone = '',
    String paymentMethod = 'cash',
    String note = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      final totalKurus = items.fold<int>(
        0,
        (sum, i) =>
            sum +
            ((i['quantity'] as num?)?.toInt() ?? 0) *
                ((i['unitPriceKurus'] as num?)?.toInt() ?? 0),
      );

      final result = await _db.from('crm_entries').insert({
        'user_id': userId,
        'type': 'sale',
        'title': customerName.isNotEmpty ? 'Satış — $customerName' : 'Satış',
        'amount': totalKurus,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'notes': note,
        'payment_method': paymentMethod,
        'source': 'direct',
        'line_items': items,
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Satış geçmişini getir (sale_screen.dart listesi).
  static Future<List<Map<String, dynamic>>> getSales({int limit = 100}) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db
          .from('crm_entries')
          .select()
          .eq('user_id', userId)
          .eq('type', 'sale')
          .order('date', ascending: false)
          .limit(limit);

      return (result as List).cast<Map<String, dynamic>>().map((e) {
        final lineItemsRaw = e['line_items'];
        return {
          'id': e['id'],
          'businessId': e['user_id'],
          'customerId': '',
          'customerName': e['customer_name'] ?? '',
          'items': lineItemsRaw is List ? lineItemsRaw : const [],
          'totalKurus': e['amount'],
          'paymentMethod': e['payment_method'] ?? 'cash',
          'note': e['notes'] ?? '',
          'source': e['source'] ?? 'direct',
          'createdAt':
              DateTime.tryParse(e['date'] as String? ?? '')
                      ?.millisecondsSinceEpoch ??
                  0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
