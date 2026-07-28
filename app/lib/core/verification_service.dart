// Hanagram — doğrulama & takipçi servisi (Supabase)
//
// İşletme/kişisel doğrulama istekleri, takip etme/bırakma,
// rozet durumu kontrolü, admin onay akışı.
import 'web_compat.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_service.dart';
import 'supabase_service.dart';

/// Doğrulama isteği türü.
enum VerificationType { personal, business }

/// Doğrulama isteği durumu.
enum VerificationStatus { pending, approved, rejected }

/// Doğrulama isteği modeli.
class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.userId,
    required this.requestType,
    this.fullName = '',
    this.tcNo = '',
    this.frontImageUrl = '',
    this.backImageUrl = '',
    this.businessName = '',
    this.taxNo = '',
    this.taxCertificateUrl = '',
    this.businessAddress = '',
    this.status = VerificationStatus.pending,
    this.adminNote = '',
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String userId;
  final VerificationType requestType;
  final String fullName;
  final String tcNo;
  final String frontImageUrl;
  final String backImageUrl;
  final String businessName;
  final String taxNo;
  final String taxCertificateUrl;
  final String businessAddress;
  final VerificationStatus status;
  final String adminNote;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory VerificationRequest.fromJson(Map<String, dynamic> j) {
    return VerificationRequest(
      id: j['id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      requestType: j['request_type'] == 'business'
          ? VerificationType.business
          : VerificationType.personal,
      fullName: j['full_name'] as String? ?? '',
      tcNo: j['tc_no'] as String? ?? '',
      frontImageUrl: j['front_image_url'] as String? ?? '',
      backImageUrl: j['back_image_url'] as String? ?? '',
      businessName: j['business_name'] as String? ?? '',
      taxNo: j['tax_no'] as String? ?? '',
      taxCertificateUrl: j['tax_certificate_url'] as String? ?? '',
      businessAddress: j['business_address'] as String? ?? '',
      status: _parseStatus(j['status'] as String?),
      adminNote: j['admin_note'] as String? ?? '',
      expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    );
  }

  static VerificationStatus _parseStatus(String? s) {
    switch (s) {
      case 'approved':
        return VerificationStatus.approved;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.pending;
    }
  }

  bool get isPending => status == VerificationStatus.pending;
  bool get isApproved => status == VerificationStatus.approved;
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class VerificationService {
  VerificationService._();

  static SupabaseClient get _db => SupabaseService.client;

  // ─── DOĞRULAMA İSTEĞİ ───

  /// Kişisel doğrulama isteği oluştur.
  static Future<String?> submitPersonalVerification({
    required String fullName,
    required String tcNo,
    required File frontImage,
    required File backImage,
  }) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return null;

      // Kullanıcının users tablosundaki id'sini bul
      final userRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', userId)
          .maybeSingle();
      final dbUserId = userRow?['id'] as String?;
      if (dbUserId == null) return null;

      // Fotoğrafları yükle
      final frontUrl = await MediaService.uploadMedia(
        frontImage,
        userId,
      );
      final backUrl = await MediaService.uploadMedia(
        backImage,
        userId,
      );

      // İstek oluştur
      final result = await _db.from('verification_requests').insert({
        'user_id': dbUserId,
        'request_type': 'personal',
        'full_name': fullName,
        'tc_no': tcNo,
        'front_image_url': frontUrl ?? '',
        'back_image_url': backUrl ?? '',
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// İşletme doğrulama isteği oluştur.
  static Future<String?> submitBusinessVerification({
    required String businessName,
    required String taxNo,
    required File taxCertificate,
    required String businessAddress,
  }) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return null;

      final userRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', userId)
          .maybeSingle();
      final dbUserId = userRow?['id'] as String?;
      if (dbUserId == null) return null;

      // Vergi levhasını yükle
      final certUrl = await MediaService.uploadMedia(
        taxCertificate,
        userId,
      );

      final result = await _db.from('verification_requests').insert({
        'user_id': dbUserId,
        'request_type': 'business',
        'business_name': businessName,
        'tax_no': taxNo,
        'tax_certificate_url': certUrl ?? '',
        'business_address': businessAddress,
      }).select('id').maybeSingle();

      return result?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcının mevcut doğrulama isteğini getir (en son).
  static Future<VerificationRequest?> getMyRequest() async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return null;

      final result = await _db
          .from('verification_requests')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (result == null) return null;
      return VerificationRequest.fromJson(result);
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcı verified mı?
  static Future<bool> isVerified(String authId) async {
    try {
      final result = await _db
          .from('users')
          .select('verified')
          .eq('auth_id', authId)
          .maybeSingle();
      return result?['verified'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─── TAKİP SİSTEMİ ───

  /// Bir kullanıcıyı takip et.
  static Future<bool> follow(String targetAuthId) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return false;

      // Kendini takip edemez
      if (userId == targetAuthId) return false;

      // Hedef kullanıcının db id'sini bul
      final targetRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', targetAuthId)
          .maybeSingle();
      final targetDbId = targetRow?['id'] as String?;
      if (targetDbId == null) return false;

      // Kendi db id'sini bul
      final myRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', userId)
          .maybeSingle();
      final myDbId = myRow?['id'] as String?;
      if (myDbId == null) return false;

      await _db.from('followers').upsert({
        'follower_id': myDbId,
        'following_id': targetDbId,
      }, onConflict: 'follower_id,following_id');

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Takibi bırak.
  static Future<bool> unfollow(String targetAuthId) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return false;

      final targetRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', targetAuthId)
          .maybeSingle();
      final targetDbId = targetRow?['id'] as String?;
      if (targetDbId == null) return false;

      final myRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', userId)
          .maybeSingle();
      final myDbId = myRow?['id'] as String?;
      if (myDbId == null) return false;

      await _db.from('followers').delete().match({
        'follower_id': myDbId,
        'following_id': targetDbId,
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı hedefi takip ediyor mu?
  static Future<bool> isFollowing(String targetAuthId) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return false;

      final myRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', userId)
          .maybeSingle();
      final myDbId = myRow?['id'] as String?;
      if (myDbId == null) return false;

      final targetRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', targetAuthId)
          .maybeSingle();
      final targetDbId = targetRow?['id'] as String?;
      if (targetDbId == null) return false;

      final result = await _db
          .from('followers')
          .select('id')
          .eq('follower_id', myDbId)
          .eq('following_id', targetDbId)
          .maybeSingle();

      return result != null;
    } catch (_) {
      return false;
    }
  }

  /// Takipçi sayısını getir (users tablosundaki cache'den).
  static Future<int> getFollowerCount(String authId) async {
    try {
      final result = await _db
          .from('users')
          .select('follower_count')
          .eq('auth_id', authId)
          .maybeSingle();
      return (result?['follower_count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Kişinin işletme grubunda olup olmadığını kontrol et.
  static Future<bool> isInBusinessGroup(
      String targetAuthId, String groupId) async {
    try {
      final targetRow = await _db
          .from('users')
          .select('id')
          .eq('auth_id', targetAuthId)
          .maybeSingle();
      final targetDbId = targetRow?['id'] as String?;
      if (targetDbId == null) return false;

      final result = await _db
          .from('group_members')
          .select('id')
          .eq('user_id', targetDbId)
          .eq('group_id', groupId)
          .maybeSingle();

      return result != null;
    } catch (_) {
      return false;
    }
  }
}
