// Hanagram — İşletme hizmet kataloğu CRUD katmanı
// services tablosu + hizmete bağlı medya (video/foto) erişimi

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Hizmet modeli — `services` tablosuna karşılık gelir.
class BusinessService {
  const BusinessService({
    required this.id,
    required this.businessId,
    required this.name,
    this.description = '',
    this.price = 0,
    this.durationMinutes = 30,
    this.category = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id;
  final String businessId;
  final String name;
  final String description;
  final int price; // kuruş
  final int durationMinutes;
  final String category;
  final int sortOrder;
  final bool isActive;

  factory BusinessService.fromJson(Map<String, dynamic> j) {
    return BusinessService(
      id: j['id'] as String? ?? '',
      businessId: j['business_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String? ?? '',
      price: (j['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 30,
      category: j['category'] as String? ?? '',
      sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      isActive: j['is_active'] as bool? ?? true,
    );
  }

  /// Kuruş cinsinden fiyatı TL'ye çevirerek Türkçe biçimde döndürür.
  /// 800000 kuruş → "₺8.000", 0 → "Belirtilmemiş".
  String get priceLabel {
    if (price == 0) return 'Belirtilmemiş';
    final tl = price ~/ 100;
    final formatted = tl.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '₺$formatted';
  }
}

/// Hizmet kataloğu CRUD + medya erişim katmanı.
/// Tüm metotlar statiktir; yetkilendirme RLS + `myDbId()` ile sağlanır.
class ServiceCatalog {
  ServiceCatalog._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Verilen işletmenin SADECE aktif hizmetlerini döndürür.
  /// Başkasının profilinde kullanılır — `myDbId()` kullanılmaz.
  static Future<List<BusinessService>> getServices(String businessId) async {
    try {
      final result = await _db
          .from('services')
          .select('*')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('sort_order')
          .order('created_at');
      return (result as List)
          .map((j) => BusinessService.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Kişinin kendi hizmetleri — pasifler DAHİL (yönetim ekranı için).
  static Future<List<BusinessService>> getMyServices() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];
      final result = await _db
          .from('services')
          .select('*')
          .eq('business_id', userId)
          .order('sort_order')
          .order('created_at');
      return (result as List)
          .map((j) => BusinessService.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Yeni hizmet oluşturur. Eklenen kaydın `id`'sini döndürür;
  /// hata ya da oturum yoksa `null`.
  static Future<String?> createService({
    required String name,
    String description = '',
    int price = 0,
    int durationMinutes = 30,
    String category = '',
    int sortOrder = 0,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;
      final result = await _db
          .from('services')
          .insert({
            'business_id': userId,
            'name': name,
            'description': description,
            'price': price,
            'duration_minutes': durationMinutes,
            'category': category,
            'sort_order': sortOrder,
          })
          .select('id')
          .single();
      return result['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Hizmet alanlarını günceller.
  static Future<bool> updateService(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db.from('services').update(data).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hizmeti siler.
  static Future<bool> deleteService(String id) async {
    try {
      await _db.from('services').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Belirli bir hizmete bağlı medya kayıtlarını (foto/video) azalan
  /// sırayla döndürür.
  static Future<List<Map<String, dynamic>>> getServiceMedia(
    String serviceId, {
    int limit = 10,
  }) async {
    try {
      final result = await _db
          .from('media')
          .select('*')
          .eq('service_id', serviceId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Belirli bir hizmete bağlı toplam medya sayısını döndürür.
  /// Profilde "+40" gibi gösterimler için kullanılır.
  static Future<int> getServiceMediaCount(String serviceId) async {
    try {
      final result = await _db
          .from('media')
          .select('id')
          .eq('service_id', serviceId);
      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Mevcut bir medya kaydının `service_id` alanını ayarlar
  /// (hizmete bağlar / bağlılığı değiştirir).
  static Future<bool> attachMedia({
    required String mediaId,
    required String serviceId,
  }) async {
    try {
      await _db
          .from('media')
          .update({'service_id': serviceId})
          .eq('id', mediaId);
      return true;
    } catch (_) {
      return false;
    }
  }
}