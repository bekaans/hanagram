// Hanagram — OneSignal web stub
//
// onesignal_flutter web'i desteklemiyor (sadece Android/iOS) — web build'i
// bu dosyayı kullanır, gerçek paketi hiç import etmez.
class OneSignalService {
  OneSignalService._();

  static Future<void> initialize(String appId) async {}
  static Future<void> tagUser(String supabaseUserId) async {}
  static Future<void> logout() async {}
}
