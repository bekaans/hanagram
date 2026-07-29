// Hanagram — bildirim servisi (OneSignal + Supabase Realtime)
//
// Tek sorumluluk: push bildirim gönderme + gerçek zamanlı dinleme.
// Web'de OneSignal çalışmaz → koşullu import ile stub kullanılır.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'onesignal_compat.dart';
import 'supabase_service.dart';

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  // ─── OneSignal Başlatma ───

  /// OneSignal'i başlat (main.dart'tan bir kez çağrılır).
  static Future<void> init() async {
    if (_initialized) return;

    try {
      OneSignalBridge.initialize('ONESIGNAL_APP_ID');
      OneSignalBridge.optIn();

      OneSignalBridge.addClickListener((event) {
        _handleNotificationClick(event);
      });
    } catch (_) {
      // OneSignal başlatılamazsa sessizce devam et
    }

    _initialized = true;
  }

  /// OneSignal user ID'sini Supabase user ID ile eşle.
  static Future<void> linkUser(String userId) async {
    try {
      OneSignalBridge.addAlias('supabase_id', userId);
    } catch (_) {}
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

  // ─── Supabase Realtime Dinleme ───

  /// Görev değişikliklerini dinle (başkası sana görev atadığında).
  static StreamSubscription<List<Map<String, dynamic>>> listenToTasks(
    String userId,
    void Function(Map<String, dynamic> task) onNewTask,
  ) {
    final controller = StreamController<Map<String, dynamic>>();

    SupabaseService.client
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

    return controller.stream.listen((task) {
      onNewTask(task);
    }) as StreamSubscription<List<Map<String, dynamic>>>;
  }

  /// Bağlantı isteklerini dinle (biri seni arkadaş olarak eklediğinde).
  static StreamSubscription<void> listenToConnectionRequests(
    String userId,
    void Function(Map<String, dynamic> request) onRequest,
  ) {
    final channel = SupabaseService.client
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
              onRequest(payload.newRecord);
            }
          },
        )
        .subscribe();

    return channel as StreamSubscription<void>;
  }

  /// Randevu değişikliklerini dinle (aynı anda hem created_by hem attendee_id).
  static void listenToAppointments(
    String userId,
    void Function(Map<String, dynamic> appointment) onChange,
  ) {
    // created_by dinleme
    SupabaseService.client
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
              onChange(payload.newRecord);
            }
          },
        )
        .subscribe();

    // attendee_id dinleme
    SupabaseService.client
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
              onChange(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  // ─── Bildirim Tıklama Yönetimi ───

  static void _handleNotificationClick(dynamic event) {
    try {
      final data = event.notification.additionalData;
      if (data == null) return;
    } catch (_) {}
    // Bildirim türüne göre yönlendirme yapılacak
    // (Flutter tarafında navigator key ile yapılabilir)
  }
}
