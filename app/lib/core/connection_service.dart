// Hanagram — bağlantı (arkadaş/çalışan) servisi
//
// Tek sorumluluk: arkadaş/çalışan ekleme, istek gönderme/kabul etme.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Bağlantı durumu.
enum ConnectionStatus { pending, accepted, rejected }

/// Bağlantı modeli.
class Connection {
  const Connection({
    required this.id,
    required this.userId,
    required this.connectedId,
    this.status = ConnectionStatus.pending,
    this.role = 'friend',
    this.createdAt,
    // Katılımcı bilgileri
    this.otherUserName = '',
    this.otherUserUsername = '',
    this.otherUserAvatar = '',
  });

  final String id;
  final String userId;
  final String connectedId;
  final ConnectionStatus status;
  final String role;
  final DateTime? createdAt;
  final String otherUserName;
  final String otherUserUsername;
  final String otherUserAvatar;

  factory Connection.fromJson(Map<String, dynamic> j) {
    final connected = j['connected'] as Map<String, dynamic>?;
    return Connection(
      id: j['id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      connectedId: j['connected_id'] as String? ?? '',
      status: _parseStatus(j['status'] as String?),
      role: j['role'] as String? ?? 'friend',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      otherUserName: connected?['full_name'] as String? ?? '',
      otherUserUsername: connected?['username'] as String? ?? '',
      otherUserAvatar: connected?['avatar_url'] as String? ?? '',
    );
  }

  static ConnectionStatus _parseStatus(String? s) {
    switch (s) {
      case 'accepted':
        return ConnectionStatus.accepted;
      case 'rejected':
        return ConnectionStatus.rejected;
      default:
        return ConnectionStatus.pending;
    }
  }
}

class ConnectionService {
  ConnectionService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Kullanıcı adıyla ara (bağlantı eklemek için).
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null || query.length < 2) return [];

      final result = await _db
          .from('users')
          .select('id, full_name, username, avatar_url, account_type')
          .neq('auth_id', userId)
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Bağlantı isteği gönder.
  static Future<bool> sendRequest(String targetUserId) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return false;

      // Zaten bağlantı var mı?
      final existing = await _db
          .from('connections')
          .select('id')
          .or(
            'and(user_id.eq.$userId,connected_id.eq.$targetUserId),'
            'and(user_id.eq.$targetUserId,connected_id.eq.$userId)',
          )
          .maybeSingle();

      if (existing != null) return false;

      await _db.from('connections').insert({
        'user_id': userId,
        'connected_id': targetUserId,
        'status': 'pending',
        'role': 'friend',
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bağlantı isteğini kabul et.
  static Future<bool> acceptRequest(String connectionId) async {
    try {
      await _db
          .from('connections')
          .update({'status': 'accepted'}).eq('id', connectionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bağlantı isteğini reddet.
  static Future<bool> rejectRequest(String connectionId) async {
    try {
      await _db
          .from('connections')
          .update({'status': 'rejected'}).eq('id', connectionId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Gelen bekleyen istekleri getir (ham map).
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return [];

      final result = await _db
          .from('connections')
          .select('''
            *,
            sender:users!connections_user_id_fkey(full_name, username, avatar_url)
          ''')
          .eq('connected_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Tüm bağlantıları getir (kabul edilenler, ham map).
  static Future<List<Map<String, dynamic>>> getMyConnections() async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return [];

      final result = await _db
          .from('connections')
          .select('''
            *,
            connected:users!connections_connected_id_fkey(full_name, username, avatar_url)
          ''')
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .order('created_at', ascending: false);

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Bağlantıyı sil.
  static Future<bool> removeConnection(String connectionId) async {
    try {
      await _db.from('connections').delete().eq('id', connectionId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
