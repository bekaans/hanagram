// Hanagram — Takvim görünümü (Supabase)
//
// Günlük görünüm: o günün görevleri + randevuları + atanan kişi.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';
import '../../core/task_service.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _selectedDate = DateTime.now();
  List<TaskItem> _tasks = [];
  List<Appointment> _appointments = [];
  DateTimeRange? _range;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDay();
  }

  Future<void> _loadDay() async {
    setState(() => _loading = true);
    final tasks = await TaskService.getTasksForDate(_selectedDate);
    final appts = await TaskService.getAppointmentsForDate(_selectedDate);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _appointments = appts;
        _loading = false;
      });
    }
  }

  /// Seçili tarih aralığındaki tüm günlerin görev ve randevularını toplar.
  Future<void> _loadRange() async {
    final r = _range;
    if (r == null) return;
    setState(() => _loading = true);
    final tasks = <TaskItem>[];
    final appts = <Appointment>[];
    var day = DateTime(r.start.year, r.start.month, r.start.day);
    final last = DateTime(r.end.year, r.end.month, r.end.day);
    // Aşırı geniş aralıkta ekranı kilitlememek için üst sınır
    var guard = 0;
    while (!day.isAfter(last) && guard < 62) {
      tasks.addAll(await TaskService.getTasksForDate(day));
      appts.addAll(await TaskService.getAppointmentsForDate(day));
      day = day.add(const Duration(days: 1));
      guard++;
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _appointments = appts;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
        title: Text('Takvim',
            style: HgText.title
                .copyWith(color: c.text, shadows: null)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildMonthGrid(c),
                const SizedBox(height: HgSpace.md),
                _loading
                    ? const Padding(
                        padding: EdgeInsets.all(HgSpace.xl),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _buildDayContent(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Aylık ızgara ───

  Widget _buildMonthGrid(HgColors c) {
    final now = DateTime.now();
    final first = DateTime(_selectedDate.year, _selectedDate.month, 1);
    // Ayın son günü: bir sonraki ayın 0. günü
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    // Pazartesi=1 … Pazar=7 → ızgarada kaç boş hücre bırakılacağı
    final leading = first.weekday - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: c.text),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                        _selectedDate.year, _selectedDate.month - 1, 1);
                  });
                  _loadDay();
                },
              ),
              const Spacer(),
              Text(
                _monthLabel(_selectedDate),
                style: HgText.heading.copyWith(color: c.text),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.chevron_right, color: c.text),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                        _selectedDate.year, _selectedDate.month + 1, 1);
                  });
                  _loadDay();
                },
              ),
            ],
          ),
          const SizedBox(height: HgSpace.sm),
          // Gün adı başlıkları — Pazartesi'den Pazar'a
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      _dayNameShort(i),
                      style: HgText.caption
                          .copyWith(color: c.textMuted, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.1,
            ),
            itemCount: leading + daysInMonth,
            itemBuilder: (context, index) {
              if (index < leading) return const SizedBox.shrink();
              final dayNum = index - leading + 1;
              final day =
                  DateTime(_selectedDate.year, _selectedDate.month, dayNum);
              final isToday = day.year == now.year &&
                  day.month == now.month &&
                  day.day == now.day;
              final isSelected = day.year == _selectedDate.year &&
                  day.month == _selectedDate.month &&
                  day.day == _selectedDate.day;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = day);
                  _loadDay();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? c.violet
                        : isToday
                            ? c.violet.withValues(alpha: 0.12)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(HgRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNum',
                      style: HgText.body.copyWith(
                        color: isSelected ? c.onBrand : c.text,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: HgSpace.sm),
          // Özel tarih / aralık seçimi
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickSingleDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: HgSpace.sm),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(HgRadius.sm),
                    ),
                    child: Center(
                      child: Text('Tarih seç',
                          style: HgText.caption.copyWith(color: c.violet)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: HgSpace.sm),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: HgSpace.sm),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(HgRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        _range == null ? 'Tarih aralığı' : 'Aralığı temizle',
                        style: HgText.caption.copyWith(color: c.violet),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_range != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_range!.start.day}.${_range!.start.month} — ${_range!.end.day}.${_range!.end.month} arası gösteriliyor',
              style: HgText.caption.copyWith(color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Tek gün seçici.
  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _range = null;
    });
    _loadDay();
  }

  /// Tarih aralığı seçici — doluysa temizler.
  Future<void> _pickDateRange() async {
    if (_range != null) {
      setState(() => _range = null);
      _loadDay();
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _loadRange();
  }

  // ─── Günün içeriği ───

  Widget _buildDayContent(HgColors c) {
    final hasItems = _tasks.isNotEmpty || _appointments.isNotEmpty;
    if (!hasItems) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available,
                size: 48, color: c.textFaint),
            const SizedBox(height: HgSpace.md),
            Text('Bu gün için bir şey yok',
                style: HgText.heading
                    .copyWith(color: c.textMuted)),
            const SizedBox(height: HgSpace.sm),
            Text(_formatFullDate(_selectedDate),
                style:
                    HgText.small.copyWith(color: c.textFaint)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDay,
      child: ListView(
        padding: const EdgeInsets.symmetric(
            horizontal: HgSpace.lg, vertical: HgSpace.sm),
        children: [
          if (_appointments.isNotEmpty) ...[
            Text('Randevular',
                style: HgText.heading
                    .copyWith(color: c.violet)),
            const SizedBox(height: HgSpace.sm),
            for (final a in _appointments)
              _apptTile(c, a),
            const SizedBox(height: HgSpace.lg),
          ],
          if (_tasks.isNotEmpty) ...[
            Text('Görevler',
                style: HgText.heading
                    .copyWith(color: c.blue)),
            const SizedBox(height: HgSpace.sm),
            for (final t in _tasks)
              _taskTile(c, t),
          ],
        ],
      ),
    );
  }

  Widget _apptTile(HgColors c, Appointment a) {
    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: c.violet,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: HgSpace.md),
          Icon(Icons.event_outlined, color: c.violet, size: 20),
          const SizedBox(width: HgSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: HgText.bodyStrong
                        .copyWith(color: c.text)),
                if (a.attendeeName.isNotEmpty)
                  Text(a.attendeeName,
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          Text(a.startTime,
              style: HgText.bodyStrong
                  .copyWith(color: c.violet)),
        ],
      ),
    );
  }

  Widget _taskTile(HgColors c, TaskItem t) {
    final isDone = t.status == TaskStatus.completed;
    return HgCard(
      padding: const EdgeInsets.all(HgSpace.md),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? c.success : c.textMuted,
            size: 20,
          ),
          const SizedBox(width: HgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title,
                    style: HgText.bodyStrong.copyWith(
                      color: c.text,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : null,
                    )),
                if (t.assigneeName.isNotEmpty)
                  Text(t.assigneeName,
                      style: HgText.caption
                          .copyWith(color: c.textMuted)),
              ],
            ),
          ),
          if (t.dueTime != null)
            Text(t.dueTime!,
                style: HgText.caption
                    .copyWith(color: c.textMuted)),
        ],
      ),
    );
  }

  // ─── Yardımcılar ───

  static const _days = [
    '', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];
  static const _months = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  String _dayNameShort(int weekday) =>
      weekday >= 1 && weekday <= 7 ? _days[weekday] : '';

  String _monthLabel(DateTime d) => '${_months[d.month]} ${d.year}';

  String _formatFullDate(DateTime d) =>
      '${d.day} ${_months[d.month]} ${d.year}';
}
