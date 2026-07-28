// Hanagram — muhasebe servisi (Supabase)
//
// Gelir/gider CRUD + aylık rapor + istatistik + karşılaştırma.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// İşlem türü.
enum TransactionType { income, expense }

/// Muhasebe kalemi modeli.
class AccountingEntry {
  const AccountingEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.date,
    this.category = '',
    this.description = '',
    this.customerName = '',
    this.crmEntryId,
    this.createdAt,
  });

  final String id;
  final TransactionType type;
  final String title;
  final int amount; // kuruş cinsinden
  final DateTime date;
  final String category;
  final String description;
  final String customerName;
  final String? crmEntryId;
  final DateTime? createdAt;

  factory AccountingEntry.fromJson(Map<String, dynamic> j) =>
      AccountingEntry(
        id: j['id'] as String? ?? '',
        type: (j['type'] as String?) == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        title: j['title'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        date: DateTime.tryParse(j['date'] as String? ?? '') ??
            DateTime.now(),
        category: j['category'] as String? ?? '',
        description: j['description'] as String? ?? '',
        customerName: j['customer_name'] as String? ?? '',
        crmEntryId: j['crm_entry_id'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );

  bool get isIncome => type == TransactionType.income;
}

/// Aylık özet rapor.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.netProfit,
    required this.transactionCount,
    required this.newCustomers,
    required this.totalAppointments,
    required this.newAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
  });

  final int month;
  final int year;
  final int totalIncome;
  final int totalExpense;
  final int netProfit;
  final int transactionCount;
  final int newCustomers;
  final int totalAppointments;
  final int newAppointments;
  final int completedAppointments;
  final int cancelledAppointments;

  double get profitMargin =>
      totalIncome > 0 ? (netProfit / totalIncome * 100) : 0;
}

class AccountingService {
  AccountingService._();

  static SupabaseClient get _db => SupabaseService.client;

  // ─── CRUD ───

  /// Yeni gelir/gider kalemi ekle.
  static Future<String?> addEntry({
    required TransactionType type,
    required String title,
    required int amount,
    required DateTime date,
    String category = '',
    String description = '',
    String customerName = '',
    String? crmEntryId,
  }) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return null;

      final result = await _db.from('accounting_entries').insert({
        'user_id': userId,
        'type': type == TransactionType.income ? 'income' : 'expense',
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'description': description,
        'customer_name': customerName,
        'crm_entry_id': crmEntryId,
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Kalemi güncelle.
  static Future<bool> updateEntry(
      String id, Map<String, dynamic> data) async {
    try {
      await _db.from('accounting_entries').update(data).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kalemi sil.
  static Future<bool> deleteEntry(String id) async {
    try {
      await _db.from('accounting_entries').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Tüm kayıtları getir (tarih aralığı filtresi ile).
  static Future<List<AccountingEntry>> getEntries({
    DateTime? from,
    DateTime? to,
    TransactionType? type,
    int limit = 200,
  }) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return [];

      var query = _db
          .from('accounting_entries')
          .select('*')
          .eq('user_id', userId);

      if (from != null) {
        query = query.gte(
            'date', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte(
            'date', to.toIso8601String());
      }
      if (type != null) {
        query = query.eq(
            'type', type == TransactionType.income ? 'income' : 'expense');
      }

      final result = await query
          .order('date', ascending: false)
          .limit(limit);

      return (result as List)
          .map((j) => AccountingEntry.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── RAPORLAR ───

  /// Belirli bir ayın özet raporunu oluştur.
  static Future<MonthlyReport> getMonthlyReport(
      int year, int month) async {
    final userId = SupabaseService.user?.id;
    if (userId == null) {
      return _emptyReport(year, month);
    }

    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59);
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    final results = await Future.wait([
      // Gelir toplamı
      _db
          .from('accounting_entries')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'income')
          .gte('date', fromStr)
          .lte('date', toStr),
      // Gider toplamı
      _db
          .from('accounting_entries')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'expense')
          .gte('date', fromStr)
          .lte('date', toStr),
      // Toplam işlem
      _db
          .from('accounting_entries')
          .select('id')
          .eq('user_id', userId)
          .gte('date', fromStr)
          .lte('date', toStr),
      // Yeni müşteriler (o ay ilk CRM kaydı olan)
      _db
          .from('crm_entries')
          .select('customer_name')
          .eq('user_id', userId)
          .gte('date', fromStr)
          .lte('date', toStr),
      // Randevular
      _db
          .from('appointments')
          .select('id, status')
          .or('created_by.eq.$userId,attendee_id.eq.$userId')
          .gte('date', from.toIso8601String().split('T').first)
          .lte('date', to.toIso8601String().split('T').first),
      // Yeni kullanıcılar (o ay kayıt olanlar — tüm kullanıcılar)
      _db
          .from('users')
          .select('id')
          .gte('created_at', fromStr)
          .lte('created_at', toStr),
    ]);

    final income = (results[0] as List)
        .fold<int>(0, (sum, r) => sum + ((r as Map)['amount'] as num? ?? 0).toInt());
    final expense = (results[1] as List)
        .fold<int>(0, (sum, r) => sum + ((r as Map)['amount'] as num? ?? 0).toInt());
    final txCount = (results[2] as List).length;

    // Benzersiz yeni müşteriler
    final crmRows = results[3] as List;
    final uniqueCustomers = <String>{};
    for (final r in crmRows) {
      final name = (r as Map)['customer_name'] as String? ?? '';
      if (name.isNotEmpty) uniqueCustomers.add(name.toLowerCase());
    }

    // Randevu istatistikleri
    final apptRows = results[4] as List;
    final totalAppts = apptRows.length;
    final completedAppts = apptRows
        .where((r) => (r as Map)['status'] == 'confirmed')
        .length;
    final cancelledAppts = apptRows
        .where((r) => (r as Map)['status'] == 'cancelled')
        .length;

    return MonthlyReport(
      month: month,
      year: year,
      totalIncome: income,
      totalExpense: expense,
      netProfit: income - expense,
      transactionCount: txCount,
      newCustomers: uniqueCustomers.length,
      totalAppointments: totalAppts,
      newAppointments: totalAppts, // tümü yeni o ay için
      completedAppointments: completedAppts,
      cancelledAppointments: cancelledAppts,
    );
  }

  /// İki ay arasındaki karşılaştırma.
  static Future<Map<String, MonthlyReport>> compareMonths(
      int year1, int month1, int year2, int month2) async {
    final r1 = await getMonthlyReport(year1, month1);
    final r2 = await getMonthlyReport(year2, month2);
    return {'current': r1, 'previous': r2};
  }

  /// Kategorilere göre gider dağılımı.
  static Future<Map<String, int>> expenseByCategory({
    DateTime? from,
    DateTime? to,
  }) async {
    final userId = SupabaseService.user?.id;
    if (userId == null) return {};

    var query = _db
        .from('accounting_entries')
        .select('category, amount')
        .eq('user_id', userId)
        .eq('type', 'expense');

    if (from != null) query = query.gte('date', from.toIso8601String());
    if (to != null) query = query.lte('date', to.toIso8601String());

    final result = await query;
    final map = <String, int>{};
    for (final row in (result as List)) {
      final cat = (row as Map)['category'] as String? ?? 'Diğer';
      final amt = ((row)['amount'] as num?)?.toInt() ?? 0;
      map[cat] = (map[cat] ?? 0) + amt;
    }
    return map;
  }

  static MonthlyReport _emptyReport(int year, int month) =>
      MonthlyReport(
        month: month,
        year: year,
        totalIncome: 0,
        totalExpense: 0,
        netProfit: 0,
        transactionCount: 0,
        newCustomers: 0,
        totalAppointments: 0,
        newAppointments: 0,
        completedAppointments: 0,
        cancelledAppointments: 0,
      );
}
