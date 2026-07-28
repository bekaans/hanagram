// Hanagram — SMS bildirim servisi
//
// Tek sorumluluk: randevu SMS'leri gönderme + hatırlatma zamanlaması.
// Supabase Edge Functions üzerinden SMS API'ye bağlanır (Twilio vb.).
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class SmsService {
  SmsService._();

  static SupabaseClient get _db => SupabaseService.client;

  /// Randevu onay SMS'i gönder — tarih ve saat bilgisiyle.
  static Future<bool> sendAppointmentConfirmation({
    required String recipientPhone,
    required String recipientName,
    required String appointmentTitle,
    required DateTime date,
    required String startTime,
  }) async {
    try {
      if (recipientPhone.isEmpty) return false;

      // Türkçe tarih formatı
      final dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      final monthNames = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

      final dayName = dayNames[date.weekday - 1];
      final monthName = monthNames[date.month - 1];
      final dateStr = '$dayName, ${date.day} $monthName ${date.year}';

      final message = 'Merhaba $recipientName, '
          '$dateStr saat $startTime için "$appointmentTitle" randevunuz onaylanmıştır. '
          'Hanagram';

      // Supabase Edge Function üzerinden gönder
      await _db.functions.invoke('send-sms', body: {
        'to': recipientPhone,
        'message': message,
      });

      // Hatırlatma zamanlaması (1 gün öncesi)
      await _scheduleReminder(
        recipientPhone: recipientPhone,
        recipientName: recipientName,
        appointmentTitle: appointmentTitle,
        date: date,
        startTime: startTime,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Randevu hatırlatma SMS'i zamanla — 1 gün öncesine.
  static Future<void> _scheduleReminder({
    required String recipientPhone,
    required String recipientName,
    required String appointmentTitle,
    required DateTime date,
    required String startTime,
  }) async {
    try {
      // Randevu tarihinden 1 gün önce, saat 18:00'de hatırlat
      final reminderDate = date.subtract(const Duration(days: 1));
      final reminderDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        18, // Akşam 18:00'de hatırlat
        0,
      );

      // Geçmiş tarihli hatırlatmaları atla
      if (reminderDateTime.isBefore(DateTime.now())) return;

      final dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      final monthNames = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

      final dayName = dayNames[date.weekday - 1];
      final monthName = monthNames[date.month - 1];
      final dateStr = '$dayName, ${date.day} $monthName ${date.year}';

      final message = 'Merhaba $recipientName, '
          'yarın ($dateStr) saat $startTime için "$appointmentTitle" randevunuz vardır. '
          'Hanagram';

      // Supabase'de hatırlatma kaydı oluştur (Edge Function zamanlayacak)
      await _db.from('scheduled_reminders').insert({
        'recipient_phone': recipientPhone,
        'message': message,
        'scheduled_for': reminderDateTime.toIso8601String(),
        'type': 'appointment_reminder',
        'status': 'pending',
      });
    } catch (_) {
      // Hatırlatma başarısız olursa ana SMS engellemez
    }
  }

  /// Satış onay SMS'i gönder.
  static Future<bool> sendSaleConfirmation({
    required String recipientPhone,
    required String recipientName,
    required String saleTitle,
    required int amount, // kuruş
  }) async {
    try {
      if (recipientPhone.isEmpty) return false;

      final amountStr = '${(amount / 100).toStringAsFixed(2)} ₺';

      final message = 'Merhaba $recipientName, '
          '"$saleTitle" işleminiz tamamlanmıştır. Tutar: $amountStr. '
          'Hanagram';

      await _db.functions.invoke('send-sms', body: {
        'to': recipientPhone,
        'message': message,
      });

      return true;
    } catch (_) {
      return false;
    }
  }
}
