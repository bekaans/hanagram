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
            id, title, date, start_time, status,
            attendee:users!appointments_attendee_id_fkey(id, auth_id, full_name),
            creator:users!appointments_created_by_fkey(full_name)
          ''')
          .eq('date', dateStr)
          .eq('status', 'pending')
          .or('created_by.eq.$userId,attendee_id.eq.$userId');

      int sentCount = 0;

      for (final appt in appointments) {
        final attendee = appt['attendee'] as Map<String, dynamic>?;
        final creator = appt['creator'] as Map<String, dynamic>?;
        final attendeeAuthId = attendee?['auth_id'] as String?;
        final creatorName = creator?['full_name'] as String? ?? 'İşletme';
        final title = appt['title'] as String? ?? 'Randevu';
        final startTime = appt['start_time'] as String? ?? '';
        final apptId = appt['id'] as String?;

        if (attendeeAuthId == null || apptId == null) continue;

        // Katılımcıya hatırlatıcı bildirim gönder
        final success = await NotificationService.sendToUser(
          targetUserId: attendeeAuthId,
          title: 'Randevu Hatırlatması',
          body:
              '$creatorName ile "$title" randevunuz yarın saat $startTime. Onaylayın veya iptal edin.',
          data: {
            'appointment_id': apptId,
            'type': 'appointment_reminder',
            'action_required': true,
          },
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

      // Oluşturucuya bildirim gönder
      if (createdBy != null && createdBy != userId) {
        final creatorProfile = await _db
            .from('users')
            .select('auth_id')
            .eq('id', createdBy)
            .maybeSingle();
        final creatorAuthId = creatorProfile?['auth_id'] as String?;

        if (creatorAuthId != null) {
          final attendeeProfile = await _db
              .from('users')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();
          final attendeeName =
              attendeeProfile?['full_name'] as String? ?? 'Birisi';

          await NotificationService.sendToUser(
            targetUserId: creatorAuthId,
            title: 'Randevu Onaylandı',
            body: '$attendeeName randevunuzu onayladı: ${appt['title']}',
            data: {
              'appointment_id': appointmentId,
              'type': 'appointment_confirmed',
            },
          );
        }
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
          .select('id, attendee_id, created_by')
          .eq('id', appointmentId)
          .maybeSingle();

      if (appt == null) return false;

      final attendeeId = appt['attendee_id'] as String?;
      final createdBy = appt['created_by'] as String?;
      if (attendeeId != userId && createdBy != userId) return false;

      await _db.from('appointments').update({
        'status': 'completed',
      }).eq('id', appointmentId);

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

      // Karşı tarafa bildirim gönder
      final notifyUserId = createdBy == userId ? attendeeId : createdBy;
      if (notifyUserId != null && notifyUserId != userId) {
        final targetProfile = await _db
            .from('users')
            .select('auth_id')
            .eq('id', notifyUserId)
            .maybeSingle();
        final targetAuthId = targetProfile?['auth_id'] as String?;

        if (targetAuthId != null) {
          final cancelerProfile = await _db
              .from('users')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();
          final cancelerName =
              cancelerProfile?['full_name'] as String? ?? 'Birisi';

          await NotificationService.sendToUser(
            targetUserId: targetAuthId,
            title: 'Randevu İptal Edildi',
            body: '$cancelerName randevunuzu iptal etti: ${appt['title']}',
            data: {
              'appointment_id': appointmentId,
              'type': 'appointment_cancelled',
            },
          );
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }
}
