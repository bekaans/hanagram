// Hanagram — randevu boş slot hesaplama katmanı
// Bir işletmenin belirli bir gündeki boş randevu saatlerini hesaplar.

import 'supabase_service.dart';
import 'working_hours_service.dart';

/// Dolu aralığı temsil eden yardımcı sınıf.
class _Busy {
  const _Busy(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

/// Randevu için tek bir boş zaman aralığı.
class AppointmentSlot {
  const AppointmentSlot({required this.start, required this.end});
  final DateTime start;
  final DateTime end;

  /// "14:30" biçiminde başlangıç saati.
  String get label =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
}

/// Boş randevu slotlarını hesaplayan saf mantık katmanı.
class AppointmentSlots {
  AppointmentSlots._();

  /// Verilen "HH:mm" veya "HH:mm:ss" metnini o günün DateTime'ına çevirir.
  static DateTime _at(DateTime day, String hhmm) {
    final p = hhmm.split(':');
    return DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(p.first) ?? 0,
      p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0,
    );
  }

  /// [date] günündeki boş randevu aralıklarını döndürür.
  static Future<List<AppointmentSlot>> freeSlots({
    required String businessId,
    required DateTime date,
    required int durationMinutes,
    int stepMinutes = 15,
  }) async {
    try {
      // 1. Çalışma saatlerini al
      final wh = await WorkingHoursService.getForDate(businessId, date);
      if (wh == null || wh.isClosed) return [];

      final dayStart = _at(date, wh.openTime);
      final dayEnd = _at(date, wh.closeTime);

      // 2. O günün dolu aralıklarını çek
      final dayStr =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      final rows = await SupabaseService.client
          .from('appointments')
          .select('start_time, end_time, service_id, status')
          .eq('date', dayStr)
          .or('created_by.eq.$businessId,attendee_id.eq.$businessId');

      // 3. Dolu aralıkları hazırla (iptal edilmişleri atla)
      final List<_Busy> busy = [];
      for (final row in rows as List) {
        final status = row['status'] as String?;
        if (status == 'cancelled') continue;

        final startRaw = row['start_time'] as String?;
        if (startRaw == null) continue;

        // "HH:mm:ss" ya da "HH:mm" — uzunluk kontrolüyle güvenli kesim
        final sLen = startRaw.length;
        final startT = _at(date, sLen >= 5 ? startRaw.substring(0, 5) : startRaw);

        final endRaw = row['end_time'] as String?;
        final DateTime endT;
        if (endRaw != null) {
          final eLen = endRaw.length;
          endT = _at(date, eLen >= 5 ? endRaw.substring(0, 5) : endRaw);
        } else {
          endT = startT.add(const Duration(minutes: 30));
        }

        busy.add(_Busy(startT, endT));
      }

      // 4. Aday slotları üret
      final List<AppointmentSlot> slots = [];
      var cursor = dayStart;
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      while (true) {
        final slotEnd = cursor.add(Duration(minutes: durationMinutes));
        if (slotEnd.isAfter(dayEnd)) break;

        // Geçmiş saat elenmesi (sadece bugün)
        if (isToday && cursor.isBefore(now)) {
          cursor = cursor.add(Duration(minutes: stepMinutes));
          continue;
        }

        // Çakışma kontrolü: slotStart < busyEnd && slotEnd > busyStart
        final bool overlaps = busy.any(
          (b) => cursor.isBefore(b.end) && slotEnd.isAfter(b.start),
        );

        if (!overlaps) {
          slots.add(AppointmentSlot(start: cursor, end: slotEnd));
        }

        cursor = cursor.add(Duration(minutes: stepMinutes));
      }

      return slots;
    } catch (_) {
      return [];
    }
  }

  /// Önümüzdeki [days] gün içinde EN YAKIN boş slotu bulur; hiç yoksa null.
  static Future<AppointmentSlot?> nextAvailable({
    required String businessId,
    required int durationMinutes,
    int days = 14,
  }) async {
    try {
      final today = DateTime.now();
      for (var i = 0; i < days; i++) {
        final day = today.add(Duration(days: i));
        final slots = await freeSlots(
          businessId: businessId,
          date: day,
          durationMinutes: durationMinutes,
        );
        if (slots.isNotEmpty) return slots.first;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}