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

  static String? _cachedDbId;

  /// Oturum açan kullanıcının `users.id`'sini döner (`auth_id` → `id` çözümü, cache'li).
  ///
  /// `user?.id` Supabase Auth kimliğidir (`auth.uid()`) — şemadaki tablolarda
  /// (tasks, appointments, crm_entries, connections, messages, accounting_entries...)
  /// foreign key'ler `auth.uid()`'e değil bu metodun döndürdüğü `users.id`'ye
  /// bakar. Yazma/okuma yapan her servis auth id yerine bunu kullanmalı.
  static Future<String?> myDbId() async {
    final authId = user?.id;
    if (authId == null) return null;
    if (_cachedDbId != null) return _cachedDbId;
    final row =
        await client.from('users').select('id').eq('auth_id', authId).maybeSingle();
    _cachedDbId = row?['id'] as String?;
    return _cachedDbId;
  }

  /// Çıkış yapılınca çağrılmalı — cache'lenmiş `users.id`'yi temizler,
  /// aksi halde aynı cihazda sonraki girişte önceki kullanıcının id'si sızabilir.
  static void clearCache() {
    _cachedDbId = null;
  }
}
