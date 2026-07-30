// Hanagram — OneSignal native implementasyonu
//
// onesignal_flutter SADECE Android/iOS destekliyor — macOS/Windows/Linux'ta
// derlenir (dart:io var) ama Platform kontrolüyle hiçbir şey yapmaz, aksi
// halde native tarafı hiç kayıtlı olmayan platformlarda MissingPluginException
// fırlatabilir.
import 'dart:io';

import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();

  static bool get _supported => Platform.isIOS || Platform.isAndroid;

  static Future<void> initialize(String appId) async {
    if (!_supported || appId.isEmpty) return;
    try {
      OneSignal.initialize(appId);
      await OneSignal.Notifications.requestPermission(true);
    } catch (_) {
      // Bildirim izni/başlatma başarısız olursa uygulama akışını bozmaz.
    }
  }

  /// Bu cihazı Supabase kullanıcı ID'siyle etiketler — Edge Function
  /// (send-notification) hedefleme için bu etiketi arıyor.
  static Future<void> tagUser(String supabaseUserId) async {
    if (!_supported || supabaseUserId.isEmpty) return;
    try {
      await OneSignal.User.addTagWithKey('supabase_id', supabaseUserId);
    } catch (_) {}
  }

  /// Çıkış yapılınca cihazın etiketini kaldır — aksi halde aynı cihazda
  /// sonra giriş yapan başka biri önceki kullanıcının bildirimlerini alabilir.
  static Future<void> logout() async {
    if (!_supported) return;
    try {
      await OneSignal.logout();
    } catch (_) {}
  }
}
