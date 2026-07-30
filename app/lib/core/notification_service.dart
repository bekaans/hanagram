// Hanagram — bildirim servisi (OneSignal push + Supabase Realtime)
//
// Push bildirimler OneSignal üzerinden Android/iOS'a, Supabase Edge
// Function (send-notification) tetikleyicisiyle gönderilir. Bu istemci
// tarafı sadece cihazı başlatıp Supabase kullanıcı ID'siyle etiketler —
// gerçek gönderim sunucu (Edge Function) tarafından yapılır.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'onesignal_service.dart';
import 'supabase_service.dart';

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  static const String _oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '3063622e-705c-4c14-8c9d-a6fa0342e750',
  );

  /// Bildirim servisini başlat (main.dart'tan bir kez çağrılır).
  static Future<void> init() async {
    if (_initialized) return;
    await OneSignalService.initialize(_oneSignalAppId);
    _initialized = true;
  }

  /// Kullanıcı Supabase user ID'sini bildirim hedefi olarak kaydet — Edge
  /// Function bu cihazı bulabilsin diye OneSignal'de "supabase_id" etiketi
  /// olarak işaretlenir.
  static Future<void> linkUser(String userId) async {
    await OneSignalService.tagUser(userId);
  }

  /// Çıkış yapılınca cihazın etiketini kaldır (bkz. OneSignalService.logout).
  static Future<void> unlinkUser() async {
    await OneSignalService.logout();
  }

  // ─── Push Bildirim Gönderme ───

  /// Belirli bir kullanıcıya bildirim gönder (Supabase Edge Function üzerinden).
  static Future<bool> sendToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.client.functions.invoke('send-notification', body: {
        'target_user_id': targetUserId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Bildirim Gelen Kutusu (kalıcı geçmiş) ───
  //
  // Push (sendToUser) sadece uygulama kapalıyken bile ulaşmaya çalışır ama
  // hiçbir iz bırakmaz. Bu bölüm notifications tablosuna kalıcı bir kayıt
  // yazar — Bildirimler ekranı bunu okur.

  /// [targetUserId] alıcının `users.id`'si olmalı (auth_id değil).
  static Future<void> record({
    required String targetUserId,
    required String type,
    required String title,
    String body = '',
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': targetUserId,
        'type': type,
        'title': title,
        'body': body,
        'data': data ?? {},
      });
    } catch (_) {}
  }

  /// Kendi bildirim geçmişimi getir (en yeni önce).
  static Future<List<Map<String, dynamic>>> getMyNotifications({
    int limit = 50,
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return [];
      final result = await SupabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (result as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<int> getUnreadCount() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return 0;
      final result = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (_) {}
  }

  static Future<void> markAllAsRead() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return;
      await SupabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {}
  }

  /// Toplu bildirim gönder (tüm kullanıcılara).
  static Future<bool> sendToAll({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await SupabaseService.client.functions.invoke('send-notification', body: {
        'target': 'all',
        'title': title,
        'body': body,
        'data': data ?? {},
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Yeni mesajları global olarak dinle (hangi konuşmada olursa olsun).
  /// Realtime filtreleri join desteklemediği için TÜM mesaj eklemelerini
  /// alır — çağıran, kendi konuşmalarından biri olup olmadığını kendisi
  /// kontrol etmeli (bkz. app_shell.dart _startRealtimeNotifications).
  static StreamSubscription<Map<String, dynamic>> listenToMessages(
    void Function(Map<String, dynamic> message) onNewMessage,
  ) {
    late final RealtimeChannel channel;
    final controller = StreamController<Map<String, dynamic>>(
      onCancel: () => SupabaseService.client.removeChannel(channel),
    );

    channel = SupabaseService.client
        .channel('messages-global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    return controller.stream.listen(onNewMessage);
  }

  // ─── Supabase Realtime Dinleme ───
  //
  // Her dinleyici tek-abonelikli bir StreamController üzerine kurulu;
  // `onCancel` ile döndürülen StreamSubscription iptal edildiğinde altındaki
  // Realtime kanalı da otomatik kapatılır (çağıran sadece `.cancel()` çağırır).

  /// Görev değişikliklerini dinle (başkası sana görev atadığında).
  static StreamSubscription<Map<String, dynamic>> listenToTasks(
    String userId,
    void Function(Map<String, dynamic> task) onNewTask,
  ) {
    late final RealtimeChannel channel;
    final controller = StreamController<Map<String, dynamic>>(
      onCancel: () => SupabaseService.client.removeChannel(channel),
    );

    channel = SupabaseService.client
        .channel('tasks-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'assigned_to',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    return controller.stream.listen(onNewTask);
  }

  /// Bağlantı isteklerini dinle (biri seni arkadaş olarak eklediğinde).
  static StreamSubscription<Map<String, dynamic>> listenToConnectionRequests(
    String userId,
    void Function(Map<String, dynamic> request) onRequest,
  ) {
    late final RealtimeChannel channel;
    final controller = StreamController<Map<String, dynamic>>(
      onCancel: () => SupabaseService.client.removeChannel(channel),
    );

    channel = SupabaseService.client
        .channel('connections-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'connections',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'connected_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    return controller.stream.listen(onRequest);
  }

  /// Randevu değişikliklerini dinle (oluşturduğun VEYA katılımcısı olduğun).
  static StreamSubscription<Map<String, dynamic>> listenToAppointments(
    String userId,
    void Function(Map<String, dynamic> appointment) onChange,
  ) {
    late final RealtimeChannel creatorChannel;
    late final RealtimeChannel attendeeChannel;
    final controller = StreamController<Map<String, dynamic>>(
      onCancel: () {
        SupabaseService.client.removeChannel(creatorChannel);
        SupabaseService.client.removeChannel(attendeeChannel);
      },
    );

    creatorChannel = SupabaseService.client
        .channel('appt-creator-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'created_by',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    attendeeChannel = SupabaseService.client
        .channel('appt-attendee-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'attendee_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
            }
          },
        )
        .subscribe();

    return controller.stream.listen(onChange);
  }
}
