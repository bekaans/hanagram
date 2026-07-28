// Hanagram — referans kodu servisi v2
//
// Her kullanıcıya 1 benzersiz referans kodu (sınırsız kullanım).
// Kod ile kayıt olma → referrer'a bildirim.
// Supabase users.my_referral_code + referrals tablosu.
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Kod doğrulama sonucu.
class VerifyResult {
  const VerifyResult({
    required this.valid,
    this.code = '',
    this.invitedBy = '',
    this.errorCode = '',
  });

  final bool valid;
  final String code;
  final String invitedBy;
  final String errorCode;
}

class ReferralService {
  ReferralService._();

  static SupabaseClient get _db => SupabaseService.client;

  // ─── Kod Üretimi ───

  /// Benzersiz 8 karakter kod üret (O/I/L yok).
  static String _generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// Kullanıcıya benzersiz referans kodu ata (yoksa üret).
  /// Profil oluşturma sırasında çağrılır.
  static Future<String> assignCode(String userId) async {
    final existing = await _db
        .from('users')
        .select('my_referral_code')
        .eq('id', userId)
        .maybeSingle();

    if (existing != null && existing['my_referral_code'] != null) {
      return existing['my_referral_code'] as String;
    }

    // Benzersiz kod üretene kadar dene
    for (var attempt = 0; attempt < 20; attempt++) {
      final code = _generateCode();
      try {
        await _db
            .from('users')
            .update({'my_referral_code': code})
            .eq('id', userId);
        return code;
      } catch (_) {
        // Unique constraint ihlali — tekrar dene
      }
    }
    throw Exception('Benzersiz referans kodu üretilemedi');
  }

  /// Kullanıcının referans kodunu getir.
  static Future<String?> getMyCode(String userId) async {
    final r = await _db
        .from('users')
        .select('my_referral_code')
        .eq('id', userId)
        .maybeSingle();
    return r?['my_referral_code'] as String?;
  }

  // ─── Kod Doğrulama (yeni kayıt akışı) ───

  /// Referans kodunu doğrula — kodu taşıyan kullanıcıyı bul.
  /// Sınırsız kullanım: kod her zaman geçerli.
  static Future<VerifyResult> verifyCode(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) {
      return const VerifyResult(valid: false, errorCode: 'ERR_EMPTY_CODE');
    }

    try {
      final owner = await _db
          .from('users')
          .select('id, full_name, my_referral_code')
          .eq('my_referral_code', code)
          .maybeSingle();

      if (owner == null) {
        return const VerifyResult(
          valid: false,
          errorCode: 'ERR_INVITE_INVALID',
        );
      }

      return VerifyResult(
        valid: true,
        code: code,
        invitedBy: owner['full_name'] as String? ?? '',
      );
    } catch (e) {
      return VerifyResult(valid: false, errorCode: 'ERR_NETWORK: $e');
    }
  }

  // ─── Referans Kaydı (kayıt sonrası) ───

  /// Yeni kullanıcı kaydolduğunda referrals tablosuna yaz + bildirim gönder.
  /// [referredId]: yeni kayıt olan kullanıcı ID
  /// [code]: kullanılan referans kodu
  static Future<void> recordReferral({
    required String referredId,
    required String code,
  }) async {
    try {
      // Kod sahibini bul
      final owner = await _db
          .from('users')
          .select('id, full_name, username')
          .eq('my_referral_code', code.trim().toUpperCase())
          .maybeSingle();

      if (owner == null) return;

      // referrals tablosuna yaz (tekrar insert engeli: UNIQUE constraint)
      final existing = await _db
          .from('referrals')
          .select('id')
          .eq('referred_id', referredId)
          .maybeSingle();

      if (existing != null) return; // Zaten kaydedilmiş

      await _db.from('referrals').insert({
        'referrer_id': owner['id'],
        'referred_id': referredId,
        'code': code.trim().toUpperCase(),
      });

      // Yeni kullanıcıya tam adı çek
      final newUser = await _db
          .from('users')
          .select('full_name')
          .eq('id', referredId)
          .maybeSingle();

      final newName = newUser?['full_name'] as String? ?? 'Bir kullanıcı';

      // Referrer'a bildirim gönder (OneSignal/notification_service)
      await _sendReferralNotification(
        targetUserId: owner['id'] as String,
        referrerName: owner['full_name'] as String? ?? '',
        newUserFullname: newName,
      );
    } catch (_) {
      // Bildirim hatası kritik değil — sessizce geç
    }
  }

  /// Referrer'a bildirim gönder.
  static Future<void> _sendReferralNotification({
    required String targetUserId,
    required String referrerName,
    required String newUserFullname,
  }) async {
    try {
      await _db.rpc('send_notification', params: {
        'target_user_id': targetUserId,
        'title': 'Yeni referans!',
        'body': '$newUserFullname senin referansın ile Hanagrama katıldı!',
        'data': const {'type': 'referral'},
      });
    } catch (_) {
      // Bildirim servisi henüz hazır değilse sessizce geç
    }
  }

  // ─── Admin / Profil Bilgileri ───

  /// Kullanıcının davet ettiği kişileri getir.
  static Future<List<Map<String, dynamic>>> getMyReferrals(
      String userId) async {
    final r = await _db
        .from('referrals')
        .select('''
          id, created_at,
          referred:users!referrals_referred_id_fkey(
            id, full_name, username, avatar_url, created_at
          )
        ''')
        .eq('referrer_id', userId)
        .order('created_at', ascending: false);
    return (r as List).cast<Map<String, dynamic>>();
  }

  /// Kullanıcı adının benzersiz olup olmadığını kontrol et.
  static Future<bool> isUsernameAvailable(String username) async {
    try {
      final result = await _db
          .from('users')
          .select('id')
          .eq('username', username.trim().toLowerCase())
          .maybeSingle();
      return result == null;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı profilini oluştur (Supabase Auth signup sonrası).
  static Future<String?> createProfile({
    required String authId,
    required String username,
    required String fullName,
    required String accountType,
    String? email,
    String? phone,
    String? referralCode,
    String? avatarUrl,
  }) async {
    try {
      final result = await _db
          .from('users')
          .insert({
            'auth_id': authId,
            'username': username.trim().toLowerCase(),
            'full_name': fullName.trim(),
            'account_type': accountType,
            'email': email,
            'phone': phone,
            'referral_code_used': referralCode?.trim().toUpperCase(),
            'avatar_url': avatarUrl,
          })
          .select('id')
          .maybeSingle();

      final userId = result?['id'] as String?;

      if (userId != null) {
        // Benzersiz referans kodu ata
        await assignCode(userId);

        // Referans kaydı (eğer kod kullanıldıysa)
        if (referralCode != null && referralCode.isNotEmpty) {
          await recordReferral(
            referredId: userId,
            code: referralCode,
          );
        }
      }

      return userId;
    } catch (e) {
      return null;
    }
  }

  /// Kullanıcı profilini getir (auth_id ile).
  static Future<Map<String, dynamic>?> getProfile(String authId) async {
    try {
      return await _db
          .from('users')
          .select()
          .eq('auth_id', authId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
