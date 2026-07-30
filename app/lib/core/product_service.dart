// Hanagram — ürün kataloğu servisi (Supabase)
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class ProductService {
  ProductService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Ürün listesini getir (isteğe bağlı isim araması).
  static Future<List<Map<String, dynamic>>> getProducts({
    String query = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      var q = _db.from('products').select().eq('owner_id', userId);
      if (query.isNotEmpty) {
        q = q.ilike('name', '%$query%');
      }
      final result = await q.order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>().map((p) {
        final updatedRaw = p['updated_at'] ?? p['created_at'];
        return {
          'id': p['id'],
          'businessId': p['owner_id'],
          'name': p['name'],
          'description': p['description'],
          'priceKurus': p['price'],
          'category': p['category'],
          'active': p['is_active'],
          'createdAt': DateTime.tryParse(p['created_at'] as String? ?? '')
                  ?.millisecondsSinceEpoch ??
              0,
          'updatedAt':
              DateTime.tryParse(updatedRaw as String? ?? '')
                      ?.millisecondsSinceEpoch ??
                  0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Yeni ürün ekle.
  static Future<bool> createProduct({
    required String name,
    String description = '',
    required int priceKurus,
    String category = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      await _db.from('products').insert({
        'owner_id': userId,
        'name': name,
        'description': description,
        'price': priceKurus,
        'category': category,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mevcut ürünü güncelle.
  static Future<bool> updateProduct({
    required String productId,
    required String name,
    String description = '',
    required int priceKurus,
    String category = '',
  }) async {
    try {
      await _db.from('products').update({
        'name': name,
        'description': description,
        'price': priceKurus,
        'category': category,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ürünü sil.
  static Future<bool> deleteProduct(String productId) async {
    try {
      await _db.from('products').delete().eq('id', productId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
