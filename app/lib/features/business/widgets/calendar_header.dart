// Hanagram — takvim başlık bileşeni
//
// Panel ekranında haftalık görünüm + gün navigasyonu.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../models/calendar_day.dart';

/// Haftalık takvim başlığı — sol/sağ ok + gün hücresi satırı.
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.onDayTap,
    required this.c,
    this.onPrevWeek,
    this.onNextWeek,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final HgColors c;
  final VoidCallback? onPrevWeek;
  final VoidCallback? onNextWeek;

  @override
  Widget build(BuildContext context) {
    final days = CalendarDay.sampleWeek(weekStart);

    return Column(
      children: [
        // Ay / yıl başlığı + navigasyon
        Row(
          children: [
            GestureDetector(
              onTap: onPrevWeek,
              child: Container(
                padding: const EdgeInsets.all(HgSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                ),
                child: Icon(CupertinoIcons.chevron_left, size: 16, color: c.textMuted),
              ),
            ),
            const SizedBox(width: HgSpace.md),
            Expanded(
              child: Text(
                _monthLabel(weekStart),
                style: HgText.heading.copyWith(color: c.text),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: HgSpace.md),
            GestureDetector(
              onTap: onNextWeek,
              child: Container(
                padding: const EdgeInsets.all(HgSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(HgRadius.sm),
                ),
                child: Icon(CupertinoIcons.chevron_right, size: 16, color: c.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: HgSpace.md),

        // Gün hücreleri
        Row(
          children: days.map((day) {
            final isToday = _isSameDay(day.date, DateTime.now());
            final isSelected = _isSameDay(day.date, selectedDay);

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayTap(day.date),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: HgSpace.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? c.violet : Colors.transparent,
                    borderRadius: BorderRadius.circular(HgRadius.sm),
                    border: isToday && !isSelected
                        ? Border.all(color: c.violet.withValues(alpha: 0.5))
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _dayShort(day.date),
                        style: HgText.caption.copyWith(
                          color: isSelected ? c.onBrand : c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${day.date.day}',
                        style: HgText.bodyStrong.copyWith(
                          color: isSelected ? c.onBrand : c.text,
                        ),
                      ),
                      if (day.appointmentCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected ? c.onBrand : c.violet,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayShort(DateTime d) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[d.weekday - 1];
  }

  static String _monthLabel(DateTime d) {
    const aylar = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${aylar[d.month]} ${d.year}';
  }
}
