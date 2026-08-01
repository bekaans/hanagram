// Hanagram — işletme değerlendirme servisi (Supabase)
//
// reviews tablosu: gerçek kullanıcı yorumu (reviewer_id dolu) veya
// işletmenin uygulama dışı aldığı değerlendirmeyi elle kaydetmesi
// (reviewer_id NULL, reviewer_name dolu).
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Bir işletmenin puan özeti — ortalama ve toplam değerlendirme sayısı.
class RatingSummary {
  const RatingSummary({this.average = 0, this.count = 0});

  final double average;
  final int count;

  bool get hasRatings => count > 0;

  /// Türkçe biçimde ortalama: 4.75 -> "4,8" (virgüllü, tek ondalık).
  String get averageLabel => average.toStringAsFixed(1).replaceAll('.', ',');
}

class ReviewService {
  ReviewService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// İşletmenin ortalama puanı ve toplam değerlendirme sayısı.
  /// [businessId] `users.id`'dir (auth id DEĞİL).
  static Future<RatingSummary> getRatingSummary(String businessId) async {
    try {
      final result = await _db
          .from('reviews')
          .select('rating')
          .eq('business_id', businessId);

      final rows = result as List;
      if (rows.isEmpty) return const RatingSummary();

      var total = 0;
      for (final r in rows) {
        total += ((r as Map)['rating'] as num?)?.toInt() ?? 0;
      }
      return RatingSummary(
        average: total / rows.length,
        count: rows.length,
      );
    } catch (_) {
      return const RatingSummary();
    }
  }

  /// Bir işletmenin aldığı yorumları getir (varsayılan: kendi işletmen).
  static Future<List<Map<String, dynamic>>> getReviews({
    String? businessId,
  }) async {
    try {
      final targetId = businessId ?? await SupabaseService.myDbId();
      if (targetId == null) return [];

      final result = await _db
          .from('reviews')
          .select('*, reviewer:users!reviews_reviewer_id_fkey(full_name)')
          .eq('business_id', targetId)
          .order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>().map((r) {
        final reviewer = r['reviewer'] as Map<String, dynamic>?;
        final hasAccount = r['reviewer_id'] != null;
        final accountName = reviewer?['full_name'] as String?;
        final name = (hasAccount ? accountName : null) ??
            (r['reviewer_name'] as String? ?? '');
        return {
          'id': r['id'],
          'name': name.isNotEmpty ? name : 'Anonim',
          'rating': r['rating'],
          'text': r['comment'] ?? '',
          'date': DateTime.tryParse(r['created_at'] as String? ?? ''),
          'isVerified': hasAccount,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// İşletmenin uygulama dışı aldığı bir değerlendirmeyi elle kaydet.
  static Future<bool> addManualReview({
    required String reviewerName,
    required int rating,
    required String comment,
  }) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return false;

      await _db.from('reviews').insert({
        'business_id': myId,
        'reviewer_name': reviewerName,
        'rating': rating,
        'comment': comment,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gerçek kullanıcı olarak bir işletmeyi değerlendir (public profil "Yorum Yap").
  static Future<bool> submitReview({
    required String businessId,
    required int rating,
    required String comment,
  }) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null || myId == businessId) return false;

      await _db.from('reviews').upsert({
        'business_id': businessId,
        'reviewer_id': myId,
        'rating': rating,
        'comment': comment,
      }, onConflict: 'business_id,reviewer_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteReview(String reviewId) async {
    try {
      await _db.from('reviews').delete().eq('id', reviewId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
