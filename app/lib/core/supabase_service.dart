// Hanagram — Supabase servis katmanı
//
// Tek sorumluluk: Supabase bağlantısı, initializasyon, client erişimi.
// Tüm Supabase çağrıları bu servis üzerinden yapılır.
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xpfankoxtqcicldbhsgu.supabase.co',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_z4rbmh4YzQ96o7jeXalBHQ_qPI0KiK9',
  );

  static bool _initialized = false;

  /// Supabase'i başlat (main.dart'tan bir kez çağrılır).
  static Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
    _initialized = true;
  }

  /// Supabase client referansı.
  static SupabaseClient get client => Supabase.instance.client;

  /// Mevcut oturum (null = giriş yapılmamış).
  static Session? get session => client.auth.currentSession;

  /// Mevcut kullanıcı (null = giriş yapılmamış).
  static User? get user => client.auth.currentUser;
}
