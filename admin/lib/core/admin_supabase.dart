// Hanagram Admin — Supabase servisi
//
// Admin panelinin Supabase'e bağlı veri katmanı.
// Kullanıcı, görev, randevu, CRM, bağlantı ve versiyon sorguları.
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSupabase {
  AdminSupabase._();

  static const String _url = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://xpfankoxtqcicldbhsgu.supabase.co');
  static const String _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_z4rbmh4YzQ96o7jeXalBHQ_qPI0KiK9');

  static Future<void> init() async {
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  // ─── Auth ───

  static Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  static Future<void> signOut() => client.auth.signOut();

  static User? get user => client.auth.currentUser;

  // ─── Genel Bakış İstatistikleri ───

  /// Toplam kullanıcı sayısı.
  static Future<int> userCount() async {
    final r = await client.from('users').select('id');
    return (r as List).length;
  }

  /// Son 24 saatte kayıt olan.
  static Future<int> joined24h() async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toIso8601String();
    final r = await client
        .from('users')
        .select('id')
        .gt('created_at', since);
    return (r as List).length;
  }

  /// Son 7 günde kayıt olan.
  static Future<int> joined7d() async {
    final since = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String();
    final r = await client
        .from('users')
        .select('id')
        .gt('created_at', since);
    return (r as List).length;
  }

  /// Son 30 günde kayıt olan.
  static Future<int> joined30d() async {
    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final r = await client
        .from('users')
        .select('id')
        .gt('created_at', since);
    return (r as List).length;
  }

  /// Hesap türüne göre sayım.
  static Future<Map<String, int>> usersByType() async {
    final r = await client.from('users').select('account_type');
    final map = <String, int>{};
    for (final row in (r as List)) {
      final t = (row as Map)['account_type'] as String? ?? 'personal';
      map[t] = (map[t] ?? 0) + 1;
    }
    return map;
  }

  /// Toplam görev sayısı.
  static Future<int> taskCount() async {
    final r = await client.from('tasks').select('id');
    return (r as List).length;
  }

  /// Toplam randevu sayısı.
  static Future<int> appointmentCount() async {
    final r = await client.from('appointments').select('id');
    return (r as List).length;
  }

  /// Toplam CRM girişi.
  static Future<int> crmCount() async {
    final r = await client.from('crm_entries').select('id');
    return (r as List).length;
  }

  /// Kullanılmamış referans kodu.
  static Future<int> unusedReferralCodes() async {
    final r = await client
        .from('referral_codes')
        .select('id')
        .eq('is_used', false);
    return (r as List).length;
  }

  /// Kullanılmış referans kodu.
  static Future<int> usedReferralCodes() async {
    final r = await client
        .from('referral_codes')
        .select('id')
        .eq('is_used', true);
    return (r as List).length;
  }

  /// Tüm istatistikleri tek seferde çek.
  static Future<Map<String, dynamic>> fetchOverview() async {
    final results = await Future.wait([
      userCount(),
      joined24h(),
      joined7d(),
      joined30d(),
      usersByType(),
      taskCount(),
      appointmentCount(),
      crmCount(),
      unusedReferralCodes(),
      usedReferralCodes(),
    ]);

    final types = results[4] as Map<String, int>;
    return {
      'users': results[0],
      'joined24h': results[1],
      'joined7d': results[2],
      'joined30d': results[3],
      'business': types['business'] ?? 0,
      'creator': types['creator'] ?? 0,
      'personal': types['personal'] ?? 0,
      'tasks': results[5],
      'appointments': results[6],
      'crm': results[7],
      'invitesOpen': results[8],
      'invitesUsed': results[9],
    };
  }

  // ─── Kullanıcılar ───

  /// Tüm kullanıcıları getir.
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final r = await client
        .from('users')
        .select('*')
        .order('created_at', ascending: false);
    return (r as List).cast<Map<String, dynamic>>();
  }

  /// Tek bir kullanıcının tam detayı.
  static Future<Map<String, dynamic>> fetchUserDetail(String authId) async {
    final results = await Future.wait([
      client.from('users').select('*').eq('auth_id', authId).maybeSingle(),
      client
          .from('tasks')
          .select('*')
          .or('created_by.eq.$authId,assigned_to.eq.$authId')
          .order('created_at', ascending: false),
      client
          .from('appointments')
          .select('*')
          .or('created_by.eq.$authId,attendee_id.eq.$authId')
          .order('date', ascending: false),
      client
          .from('crm_entries')
          .select('*')
          .eq('user_id', authId)
          .order('date', ascending: false),
      client
          .from('connections')
          .select('''
            id, status, role, created_at,
            connected:users!connections_connected_id_fkey(id, full_name, username, avatar_url)
          ''')
          .eq('user_id', authId),
    ]);

    return {
      'profile': results[0],
      'tasks': results[1],
      'appointments': results[2],
      'crm': results[3],
      'connections': results[4],
    };
  }

  // ─── Görevler ───

  static Future<List<Map<String, dynamic>>> fetchAllTasks({int limit = 200}) =>
      client
          .from('tasks')
          .select('''
            *,
            creator:users!tasks_created_by_fkey(full_name, username),
            assignee:users!tasks_assigned_to_fkey(full_name, username)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

  // ─── Randevular ───

  static Future<List<Map<String, dynamic>>> fetchAllAppointments(
          {int limit = 200}) =>
      client
          .from('appointments')
          .select('''
            *,
            creator:users!appointments_created_by_fkey(full_name, username),
            attendee:users!appointments_attendee_id_fkey(full_name, username)
          ''')
          .order('date', ascending: false)
          .limit(limit);

  // ─── CRM ───

  static Future<List<Map<String, dynamic>>> fetchAllCrm({int limit = 200}) =>
      client
          .from('crm_entries')
          .select('*')
          .order('date', ascending: false)
          .limit(limit);

  // ─── Versiyon Yönetimi ───

  static Future<List<Map<String, dynamic>>> fetchVersions() => client
      .from('app_versions')
      .select('*')
      .order('created_at', ascending: false);

  static Future<void> addVersion({
    required String version,
    required int buildNumber,
    required String platform,
    required String downloadUrl,
    String changelog = '',
    bool isForce = false,
    bool isActive = true,
  }) =>
      client.from('app_versions').insert({
        'version': version,
        'build_number': buildNumber,
        'platform': platform,
        'download_url': downloadUrl,
        'changelog': changelog,
        'is_force': isForce,
        'is_active': isActive,
      });

  static Future<void> updateVersion(
          String id, Map<String, dynamic> data) =>
      client.from('app_versions').update(data).eq('id', id);

  static Future<void> deleteVersion(String id) =>
      client.from('app_versions').delete().eq('id', id);

  // ─── Referans Kodları ───

  static Future<List<Map<String, dynamic>>> fetchReferrals() async {
    final r = await client
        .from('referrals')
        .select('''
          id, referrer_id, referred_id, code, created_at,
          referrer:users!referrals_referrer_id_fkey(id, full_name, username),
          referred:users!referrals_referred_id_fkey(id, full_name, username)
        ''')
        .order('created_at', ascending: false);
    return (r as List).cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> fetchReferralCodes({
    bool? used,
    int limit = 100,
  }) async {
    var query = client.from('referral_codes').select('*');
    if (used != null) query = query.eq('is_used', used);
    final r = await query.order('created_at', ascending: false).limit(limit);
    return (r as List).cast<Map<String, dynamic>>();
  }

  /// Benzersiz referans kodları üret (8 karakter, harf+rakam, O/I/L yok).
  static Future<void> generateReferrals({int count = 10}) async {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final existing = await client.from('referral_codes').select('code');
    final existingCodes = (existing as List)
        .map((e) => (e as Map)['code'] as String)
        .toSet();

    final newCodes = <String>[];
    while (newCodes.length < count) {
      final code = List.generate(
          8, (_) => chars[DateTime.now().microsecondsSinceEpoch % chars.length]).join();
      if (!existingCodes.contains(code) && !newCodes.contains(code)) {
        newCodes.add(code);
        existingCodes.add(code);
      }
    }

    await client.from('referral_codes').insert(
      newCodes.map((code) => {'code': code, 'is_used': false}).toList(),
    );
  }
}
