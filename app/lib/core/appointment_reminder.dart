// Hanagram — randevu hatırlatma + onay/red bildirim sistemi
//
// Tek sorumluluk: yarınki randevuları bul, 3 saatte bir hatırlat,
// onay/red bildirimlerini işle.
// Gün içinde sadece onaylanmamış randevulara bildirim gönderilir.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';
import 'supabase_service.dart';

class AppointmentReminder {
  AppointmentReminder._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Yarınki onaylanmamış randevuları bul ve hatırlatıcı bildirim gönder.
  /// Her 3 saatte bir çağrılmalı (uygulama açılırken veya arka planda).
  static Future<int> sendReminders() async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return 0;

      // Yarının tarihini hesapla
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final dateStr = tomorrow.toIso8601String().split('T').first;

      // Yarınki onaylanmamış randevuları bul
      final appointments = await _db
          .from('appointments')
          .select('''
            id, title, date, start_time, status, attendee_id,
            creator:users!appointments_created_by_fkey(full_name)
          ''')
          .eq('date', dateStr)
          .eq('status', 'pending')
          .or('created_by.eq.$userId,attendee_id.eq.$userId');

      int sentCount = 0;

      for (final appt in appointments) {
        final creator = appt['creator'] as Map<String, dynamic>?;
        // NotificationService.sendToUser OneSignal'in "supabase_id" etiketiyle
        // eşleşmesi için users.id (dbId) bekliyor — auth_id DEĞİL.
        final attendeeDbId = appt['attendee_id'] as String?;
        final creatorName = creator?['full_name'] as String? ?? 'İşletme';
        final title = appt['title'] as String? ?? 'Randevu';
        final startTime = appt['start_time'] as String? ?? '';
        final apptId = appt['id'] as String?;

        if (attendeeDbId == null || apptId == null) continue;

        final body =
            '$creatorName ile "$title" randevunuz yarın saat $startTime. Onaylayın veya iptal edin.';
        // Katılımcıya hatırlatıcı bildirim gönder
        final success = await NotificationService.sendToUser(
          targetUserId: attendeeDbId,
          title: 'Randevu Hatırlatması',
          body: body,
          data: {
            'appointment_id': apptId,
            'type': 'appointment_reminder',
            'action_required': true,
          },
        );
        await NotificationService.record(
          targetUserId: attendeeDbId,
          type: 'appointment',
          title: 'Randevu Hatırlatması',
          body: body,
          data: {'appointment_id': apptId},
        );

        if (success) sentCount++;
      }

      return sentCount;
    } catch (_) {
      return 0;
    }
  }

  /// Randevuyu onayla.
  static Future<bool> confirmAppointment(String appointmentId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      // Randevunun sahibi mi kontrol et (AuthZ — guvenli-kod kuralı 4)
      final appt = await _db
          .from('appointments')
          .select('id, attendee_id, created_by, title')
          .eq('id', appointmentId)
          .maybeSingle();

      if (appt == null) return false;

      final attendeeId = appt['attendee_id'] as String?;
      final createdBy = appt['created_by'] as String?;

      // Sadece katılımcı veya oluşturan onaylayabilir
      if (attendeeId != userId && createdBy != userId) return false;

      await _db.from('appointments').update({
        'status': 'confirmed',
      }).eq('id', appointmentId);

      // Oluşturucuya bildirim gönder (createdBy zaten dbId — auth_id lookup'a gerek yok)
      if (createdBy != null && createdBy != userId) {
        final attendeeProfile = await _db
            .from('users')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        final attendeeName =
            attendeeProfile?['full_name'] as String? ?? 'Birisi';
        final body = '$attendeeName randevunuzu onayladı: ${appt['title']}';

        await NotificationService.sendToUser(
          targetUserId: createdBy,
          title: 'Randevu Onaylandı',
          body: body,
          data: {
            'appointment_id': appointmentId,
            'type': 'appointment_confirmed',
          },
        );
        await NotificationService.record(
          targetUserId: createdBy,
          type: 'appointment',
          title: 'Randevu Onaylandı',
          body: body,
          data: {'appointment_id': appointmentId},
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Randevuyu tamamlandı olarak işaretle (onaylanmış bir randevu için).
  static Future<bool> completeAppointment(String appointmentId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      final appt = await _db
          .from('appointments')
          .select('id, attendee_id, created_by, title')
          .eq('id', appointmentId)
          .maybeSingle();

      if (appt == null) return false;

      final attendeeId = appt['attendee_id'] as String?;
      final createdBy = appt['created_by'] as String?;
      if (attendeeId != userId && createdBy != userId) return false;

      await _db.from('appointments').update({
        'status': 'completed',
      }).eq('id', appointmentId);

      final notifyUserId = createdBy == userId ? attendeeId : createdBy;
      if (notifyUserId != null && notifyUserId != userId) {
        final body = '"${appt['title']}" randevusu tamamlandı olarak işaretlendi';
        NotificationService.sendToUser(
          targetUserId: notifyUserId,
          title: 'Randevu Tamamlandı',
          body: body,
          data: {
            'appointment_id': appointmentId,
            'type': 'appointment_completed',
          },
        );
        NotificationService.record(
          targetUserId: notifyUserId,
          type: 'appointment',
          title: 'Randevu Tamamlandı',
          body: body,
          data: {'appointment_id': appointmentId},
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Randevuyu iptal et.
  static Future<bool> cancelAppointment(String appointmentId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      // Randevunun sahibi mi kontrol et (AuthZ)
      final appt = await _db
          .from('appointments')
          .select('id, attendee_id, created_by, title')
          .eq('id', appointmentId)
          .maybeSingle();

      if (appt == null) return false;

      final attendeeId = appt['attendee_id'] as String?;
      final createdBy = appt['created_by'] as String?;

      if (attendeeId != userId && createdBy != userId) return false;

      await _db.from('appointments').update({
        'status': 'cancelled',
      }).eq('id', appointmentId);

      // Karşı tarafa bildirim gönder (notifyUserId zaten dbId)
      final notifyUserId = createdBy == userId ? attendeeId : createdBy;
      if (notifyUserId != null && notifyUserId != userId) {
        final cancelerProfile = await _db
            .from('users')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        final cancelerName =
            cancelerProfile?['full_name'] as String? ?? 'Birisi';
        final body = '$cancelerName randevunuzu iptal etti: ${appt['title']}';

        await NotificationService.sendToUser(
          targetUserId: notifyUserId,
          title: 'Randevu İptal Edildi',
          body: body,
          data: {
            'appointment_id': appointmentId,
            'type': 'appointment_cancelled',
          },
        );
        await NotificationService.record(
          targetUserId: notifyUserId,
          type: 'appointment',
          title: 'Randevu İptal Edildi',
          body: body,
          data: {'appointment_id': appointmentId},
        );
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
