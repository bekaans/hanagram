// Hanagram — mesajlaşma servisi
//
// Tek sorumluluk: DM CRUD + real-time abonelik.
// conversations, conversation_members, messages tablolarıyla çalışır.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'message_models.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class MessageService {
  MessageService._();

  static SupabaseClient get _db => SupabaseService.client;

  // ─── DM Konuşma: Bul veya Oluştur ───

  /// Mevcut DM varsa onu dön, yoksa yeni oluştur.
  static Future<String?> findOrCreateDm(String otherUserId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      // 1. Mevcut DM kontrolü: iki üyeli, dm tipinde
      final myMemberships = await _db
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', userId);

      final memberships =
          (myMemberships as List).cast<Map<String, dynamic>>();

      if (memberships.isNotEmpty) {
        final convIds =
            memberships.map((m) => m['conversation_id'] as String).toList();

        final existing = await _db
            .from('conversation_members')
            .select('conversation_id')
            .inFilter('conversation_id', convIds)
            .eq('user_id', otherUserId)
            .limit(1);

        final existingList =
            (existing as List).cast<Map<String, dynamic>>();
        if (existingList.isNotEmpty) {
          return existingList[0]['conversation_id'] as String;
        }
      }

      // 2. Yeni DM oluştur
      final conv = await _db
          .from('conversations')
          .insert({
            'type': 'dm',
            'created_by': userId,
          })
          .select('id')
          .maybeSingle();

      final convId = conv?['id'] as String?;
      if (convId == null) return null;

      // 3. Her iki üyeyi ekle
      await _db.from('conversation_members').insert([
        {'conversation_id': convId, 'user_id': userId},
        {'conversation_id': convId, 'user_id': otherUserId},
      ]);

      return convId;
    } catch (_) {
      return null;
    }
  }

  // ─── Ekip Sohbeti: Bul veya Oluştur ───

  /// Bir ekibin grup konuşmasını bul, yoksa (üye listesiyle) oluştur.
  static Future<String?> findOrCreateTeamConversation(
    String groupId,
    String teamName,
    List<String> memberUserIds,
  ) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      final existing = await _db
          .from('conversations')
          .select('id')
          .eq('team_id', groupId)
          .maybeSingle();
      if (existing != null) return existing['id'] as String?;

      final conv = await _db
          .from('conversations')
          .insert({
            'type': 'group',
            'name': teamName,
            'team_id': groupId,
            'created_by': userId,
          })
          .select('id')
          .maybeSingle();

      final convId = conv?['id'] as String?;
      if (convId == null) return null;

      final memberSet = {...memberUserIds, userId};
      await _db.from('conversation_members').insert(
        memberSet.map((id) => {'conversation_id': convId, 'user_id': id}).toList(),
      );

      return convId;
    } catch (_) {
      return null;
    }
  }

  // ─── Thread Listesi ───

  /// Kullanıcının tüm DM konuşmalarını son mesajla birlikte getir.
  static Future<List<MessageThread>> getThreads() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      // 1. Kullanıcının üye olduğu konuşmaları bul
      final memberships = await _db
          .from('conversation_members')
          .select('conversation_id, last_read_at')
          .eq('user_id', userId);

      final memberList = (memberships as List).cast<Map<String, dynamic>>();
      if (memberList.isEmpty) return [];

      final threads = <MessageThread>[];

      for (final m in memberList) {
        final convId = m['conversation_id'] as String;
        final lastReadAt =
            DateTime.tryParse(m['last_read_at'] as String? ?? '') ??
                DateTime.now();

        // Karşı tarafı bul
        final otherMembers = await _db
            .from('conversation_members')
            .select('user_id')
            .eq('conversation_id', convId)
            .neq('user_id', userId)
            .limit(1);

        final others =
            (otherMembers as List).cast<Map<String, dynamic>>();
        if (others.isEmpty) continue;

        final otherUserId = others[0]['user_id'] as String;

        // Kullanıcı bilgisi
        final userData = await _db
            .from('users')
            .select('full_name, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();

        // Son mesaj
        final lastMsg = await _db
            .from('messages')
            .select('content, created_at')
            .eq('conversation_id', convId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // Okunmamış mesaj sayısı
        final unreadResult = await _db
            .from('messages')
            .select('id')
            .eq('conversation_id', convId)
            .neq('sender_id', userId)
            .gt('created_at', lastReadAt.toUtc().toIso8601String());

        final unreadCount =
            (unreadResult as List).length;

        threads.add(MessageThread(
          conversationId: convId,
          otherUserId: otherUserId,
          otherUserName: userData?['full_name'] as String? ?? '',
          otherUserAvatar: userData?['avatar_url'] as String? ?? '',
          lastMessage: lastMsg?['content'] as String? ?? '',
          lastAt: DateTime.tryParse(lastMsg?['created_at'] as String? ?? '') ??
              DateTime.now(),
          unreadCount: unreadCount,
        ));
      }

      // Son mesaj zamanına göre sırala
      threads.sort((a, b) => b.lastAt.compareTo(a.lastAt));
      return threads;
    } catch (_) {
      return [];
    }
  }

  // ─── Mesaj Listesi ───

  /// Bir konuşmanın mesajlarını sayfalı olarak getir.
  static Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      var query = _db
          .from('messages')
          .select()
          .eq('conversation_id', conversationId);

      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }

      final result = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (result as List).cast<Map<String, dynamic>>();
      return list
          .map((j) => ChatMessage.fromJson(j, currentUserId: userId))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (_) {
      return [];
    }
  }

  // ─── Mesaj Gönder ───

  static Future<bool> sendMessage(
    String conversationId,
    String content, {
    String type = 'text',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      await _db.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': userId,
        'content': content,
        'type': type,
      });

      // Karşı tarafa bildirim gönder
      final otherMembers = await _db
          .from('conversation_members')
          .select('user_id')
          .eq('conversation_id', conversationId)
          .neq('user_id', userId);

      final others = (otherMembers as List).cast<Map<String, dynamic>>();
      for (final m in others) {
        final targetId = m['user_id'] as String;
        await NotificationService.sendToUser(
          targetUserId: targetId,
          title: 'Yeni mesaj',
          body: content.length > 50
              ? '${content.substring(0, 50)}...'
              : content,
          data: {'type': 'message', 'conversation_id': conversationId},
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Okundu İşaretle ───

  static Future<void> markAsRead(String conversationId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return;

      await _db.from('conversation_members').update({
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
      }).match({
        'conversation_id': conversationId,
        'user_id': userId,
      });
    } catch (_) {}
  }

  /// Bir DM'de KARŞI TARAFIN son okuma zamanını + "okundu bilgisi" tercihini
  /// getirir (Ayarlar → Gizlilik → "Okundu bilgisi" — karşı taraf kapattıysa
  /// hiçbir şey gösterilmemeli, kendi tercihim değil ONLARIN tercihi geçerli).
  static Future<({DateTime? lastReadAt, bool showsReceipts})> getOtherReadReceipt(
      String conversationId) async {
    try {
      final myId = await SupabaseService.myDbId();
      if (myId == null) return (lastReadAt: null, showsReceipts: false);

      final result = await _db
          .from('conversation_members')
          .select('last_read_at, users(show_read_receipts)')
          .eq('conversation_id', conversationId)
          .neq('user_id', myId)
          .maybeSingle();

      if (result == null) return (lastReadAt: null, showsReceipts: false);
      final user = result['users'] as Map<String, dynamic>?;
      final shows = user?['show_read_receipts'] as bool? ?? true;
      final lastReadAt =
          DateTime.tryParse(result['last_read_at'] as String? ?? '');
      return (lastReadAt: lastReadAt, showsReceipts: shows);
    } catch (_) {
      return (lastReadAt: null, showsReceipts: false);
    }
  }

  // ─── Real-time: Yeni Mesaj Dinleyicisi ───

  static RealtimeChannel? _messagesChannel;

  static Stream<ChatMessage> subscribeToMessages(String conversationId) {
    final controller = StreamController<ChatMessage>();

    _messagesChannel?.unsubscribe();
    SupabaseService.myDbId().then((userId) {
      _messagesChannel = _db
          .channel('messages-$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              if (payload.newRecord.isNotEmpty) {
                final msg = ChatMessage.fromJson(
                  payload.newRecord,
                  currentUserId: userId ?? '',
                );
                controller.add(msg);
              }
            },
          )
          .subscribe();
    });

    return controller.stream;
  }

  static void unsubscribeMessages() {
    _messagesChannel?.unsubscribe();
    _messagesChannel = null;
  }

  // ─── Real-time: Thread Listesi Yenileme ───

  static RealtimeChannel? _threadsChannel;

  static Stream<void> subscribeToThreads() {
    final controller = StreamController<void>();

    _threadsChannel?.unsubscribe();
    SupabaseService.myDbId().then((userId) {
      if (userId == null) return;
      _threadsChannel = _db
          .channel('threads-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversation_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) => controller.add(null),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (_) => controller.add(null),
          )
          .subscribe();
    });

    return controller.stream;
  }

  static void unsubscribeThreads() {
    _threadsChannel?.unsubscribe();
    _threadsChannel = null;
  }

  // ─── Kişi Listesi (Yeni Mesaj için) ───

  /// Arama sorgusuna göre kullanıcı listesi.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final userId = SupabaseService.user?.id;
      if (userId == null) return [];

      final result = await _db
          .from('users')
          .select('id, full_name, username, avatar_url')
          .neq('auth_id', userId)
          .or('username.ilike.%$query%,full_name.ilike.%$query%')
          .limit(20);

      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Kullanıcının bağlantılarındaki kişileri getir.
  static Future<List<Map<String, dynamic>>> getConnections() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];

      final result = await _db.from('connections').select('''
            connected_id,
            user:users!connections_connected_id_fkey(
              id, full_name, username, avatar_url
            )
          ''').eq('user_id', userId).eq('status', 'accepted');

      final list = (result as List).cast<Map<String, dynamic>>();
      return list
          .map((r) => r['user'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }
}
