// Hanagram — bildirim servisi (Supabase Realtime)
//
// Tek sorumluluk: push bildirim gönderme + gerçek zamanlı dinleme.
// Push bildirimler Supabase Edge Function üzerinden gönderilir.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  /// Bildirim servisini başlat (main.dart'tan bir kez çağrılır).
  static Future<void> init() async {
    if (_initialized) return;
    // Push bildirim Supabase Edge Function üzerinden gönderilir,
    // istemci tarafında başlatılacak bir şey yok.
    _initialized = true;
  }

  /// Kullanıcı Supabase user ID'sini bildirim hedefi olarak kaydet.
  static Future<void> linkUser(String userId) async {
    // Supabase Edge Function zaten auth.uid() kullanarak
    // hedef kullanıcıyı belirler. Ek kayıt gerekmez.
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
