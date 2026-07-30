// Hanagram — reklam kampanyası servisi (Supabase)
//
// CRUD gerçek. Gösterim/tıklama sayıları (impressions/clicks) gerçek
// kolonlar ama feed'e reklam enjekte eden bir sunum sistemi henüz yok —
// bu yüzden her zaman 0 döner, sahte sayı üretilmez.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class AdService {
  AdService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// İşletmenin reklamlarını getir (isteğe bağlı arama).
  static Future<List<Map<String, dynamic>>> getAds({String query = ''}) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      var q = _db.from('ads').select().eq('owner_id', userId);
      if (query.isNotEmpty) {
        q = q.ilike('title', '%$query%');
      }
      final result = await q.order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>().map((a) {
        final topics = a['target_topics'];
        return {
          'id': a['id'],
          'businessId': a['owner_id'],
          'title': a['title'],
          'description': a['description'],
          'imageUrl': a['image_url'],
          'targetTopics': topics is List ? topics : const [],
          'dailyBudgetKurus': a['daily_budget_kurus'],
          'bid': (a['bid'] as num?)?.toDouble() ?? 1.0,
          'status': a['status'],
          'impressions': a['impressions'],
          'clicks': a['clicks'],
          'createdAt': DateTime.tryParse(a['created_at'] as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
          'updatedAt': DateTime.tryParse(
                      (a['updated_at'] ?? a['created_at']) as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> createAd({
    required String title,
    String description = '',
    required int dailyBudgetKurus,
    double bid = 1.0,
    List<String> targetTopics = const [],
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      await _db.from('ads').insert({
        'owner_id': userId,
        'title': title,
        'description': description,
        'daily_budget_kurus': dailyBudgetKurus,
        'bid': bid,
        'target_topics': targetTopics,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateAd({
    required String adId,
    String? title,
    String? description,
    int? dailyBudgetKurus,
    double? bid,
    List<String>? targetTopics,
    String? status,
  }) async {
    try {
      final data = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (dailyBudgetKurus != null) data['daily_budget_kurus'] = dailyBudgetKurus;
      if (bid != null) data['bid'] = bid;
      if (targetTopics != null) data['target_topics'] = targetTopics;
      if (status != null) data['status'] = status;

      await _db.from('ads').update(data).eq('id', adId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteAd(String adId) async {
    try {
      await _db.from('ads').delete().eq('id', adId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
