// Hanagram — takvim günü veri modeli

class CalendarDay {
  const CalendarDay({
    required this.date,
    this.appointmentCount = 0,
    this.hasTask = false,
  });

  final DateTime date;
  final int appointmentCount;
  final bool hasTask;

  static List<CalendarDay> sampleWeek(DateTime weekStart) {
    return List.generate(7, (i) {
      final date = weekStart.add(Duration(days: i));
      final day = date.day;
      const counts = {
        25: 2,
        26: 3,
        27: 1,
        29: 4,
        30: 1,
        31: 2,
      };
      final count = counts[day] ?? 0;
      return CalendarDay(
        date: date,
        appointmentCount: count,
        hasTask: count > 0,
      );
    });
  }
}
