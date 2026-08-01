// Hanagram — Müşteri tarafından ön görüşme randevusu oluşturma servisi
import 'supabase_service.dart';
import 'notification_service.dart';

class BookingService {
  const BookingService._();

  /// Müşterinin ön görüşme randevusu talebi oluşturur.
  /// Başarılıysa randevu id'sini, aksi halde null döner.
  static Future<String?> requestConsultation({
    required String businessId,
    required String businessName,
    required String serviceId,
    required String serviceName,
    required DateTime slotStart,
    required int durationMinutes,
    required String phone,
    String note = '',
  }) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return null;

      // Kendi işletmesine randevu alamaz
      if (userId == businessId) return null;

      // Telefonu doğrula: sadece rakamlar ve en az 10 hane
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 10) return null;

      // Tarih/saat metinleri
      final dateStr = '${slotStart.year.toString().padLeft(4, '0')}-'
          '${slotStart.month.toString().padLeft(2, '0')}-'
          '${slotStart.day.toString().padLeft(2, '0')}';
      String hhmm(DateTime d) =>
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      final end = slotStart.add(Duration(minutes: durationMinutes));

      // Randevuyu ekle
      final result = await SupabaseService.client
          .from('appointments')
          .insert({
        'title': 'Ön görüşme — $serviceName',
        'description': note,
        'created_by': userId,
        'attendee_id': businessId,
        'date': dateStr,
        'start_time': hhmm(slotStart),
        'end_time': hhmm(end),
        'status': 'pending',
        'type': 'consultation',
        'service_id': serviceId,
        'customer_phone': digits,
        'note': note,
      }).select('id').maybeSingle();

      final apptId = result?['id'] as String?;
      if (apptId == null) return null;

      // Telefonu kullanıcının profiline yaz — SADECE boşsa
      final me = await SupabaseService.client
          .from('users')
          .select('phone')
          .eq('id', userId)
          .maybeSingle();
      final existing = me?['phone'] as String?;
      if (existing == null || existing.isEmpty) {
        await SupabaseService.client
            .from('users')
            .update({'phone': digits})
            .eq('id', userId);
      }

      // İşletmeye bildir
      await NotificationService.sendToUser(
        targetUserId: businessId,
        title: 'Yeni randevu talebi',
        body: '$serviceName için ön görüşme talebi geldi.',
        data: {'type': 'appointment', 'appointment_id': apptId},
      );
      await NotificationService.record(
        targetUserId: businessId,
        type: 'appointment',
        title: 'Yeni randevu talebi',
        body: '$serviceName için ön görüşme talebi geldi.',
        data: {'appointment_id': apptId},
      );

      return apptId;
    } catch (_) {
      return null;
    }
  }

  /// Müşterinin bu işletmede zaten bekleyen bir ön görüşme talebi var mı?
  static Future<bool> hasPendingRequest(String businessId) async {
    try {
      final userId = await SupabaseService.myDbId();
      if (userId == null) return false;

      final result = await SupabaseService.client
          .from('appointments')
          .select('id')
          .eq('created_by', userId)
          .eq('attendee_id', businessId)
          .eq('type', 'consultation')
          .eq('status', 'pending')
          .limit(1);

      return (result as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}