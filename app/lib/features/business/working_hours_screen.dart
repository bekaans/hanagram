// Hanagram — İşletme haftalık çalışma saatleri ekranı
// Bu ekran, işletmenin hangi saatlerde randevu kabul edeceğini belirler.
import 'package:flutter/material.dart';
import 'package:hanagram_design/design.dart';
import '../../core/working_hours_service.dart';

class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  // DB weekday -> kayıt
  final Map<int, WorkingHours> _byWeekday = {};
  bool _loading = true;
  // O an kaydedilen günler
  final Set<int> _saving = {};

  // Ekranda gösterilecek gün sırası (Pazartesi'den Pazar'a)
  static const List<int> _weekdayOrder = [1, 2, 3, 4, 5, 6, 0];

  // Model nesnesi üretmeden gün adlarını göstermek için
  static const _dayNames = {
    1: 'Pazartesi',
    2: 'Salı',
    3: 'Çarşamba',
    4: 'Perşembe',
    5: 'Cuma',
    6: 'Cumartesi',
    0: 'Pazar',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await WorkingHoursService.getMine();
    if (!mounted) return;
    final map = <int, WorkingHours>{};
    for (final wh in list) {
      map[wh.weekday] = wh;
    }
    setState(() {
      _byWeekday
        ..clear()
        ..addAll(map);
      _loading = false;
    });
  }

  Future<void> _save(
    int weekday, {
    String? open,
    String? close,
    bool? closed,
  }) async {
    final cur = _byWeekday[weekday];
    final newOpen = open ?? cur?.openTime ?? '09:00';
    final newClose = close ?? cur?.closeTime ?? '18:00';
    final newClosed = closed ?? cur?.isClosed ?? false;

    // Kapanış > açılış doğrulaması (sadece gün açıkken)
    if (!newClosed) {
      final openParts = newOpen.split(':');
      final closeParts = newClose.split(':');
      final openMin =
          int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMin =
          int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
      if (closeMin <= openMin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kapanış saati açılıştan sonra olmalı.'),
            ),
          );
        }
        return;
      }
    }

    setState(() => _saving.add(weekday));
    final ok = await WorkingHoursService.setDay(
      weekday: weekday,
      openTime: newOpen,
      closeTime: newClose,
      isClosed: newClosed,
    );
    if (!mounted) return;
    setState(() => _saving.remove(weekday));
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilemedi, tekrar deneyin.')),
      );
    }
  }

  Future<void> _pickTime(int weekday, bool isOpening) async {
    final cur = _byWeekday[weekday];
    final current =
        isOpening ? (cur?.openTime ?? '09:00') : (cur?.closeTime ?? '18:00');
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? (isOpening ? 9 : 18),
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      ),
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _save(
      weekday,
      open: isOpening ? formatted : null,
      close: isOpening ? null : formatted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çalışma Saatleri'),
        backgroundColor: c.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(HgSpace.lg),
              children: [
                Text(
                  'Müşterilerin randevu alabilmesi için çalışma saatlerini belirle. '
                  'Saat girilmeyen günlerde randevu alınamaz.',
                  style: HgText.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: HgSpace.md),
                ..._weekdayOrder.map((wd) => _buildDayRow(wd, c)),
              ],
            ),
    );
  }

  Widget _buildDayRow(int weekday, HgColors c) {
    final wh = _byWeekday[weekday];
    final closed = wh?.isClosed ?? false;
    final isSaving = _saving.contains(weekday);
    final openTime = wh?.openTime ?? '09:00';
    final closeTime = wh?.closeTime ?? '18:00';
    final dayName = _dayNames[weekday] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: HgSpace.sm),
      child: HgCard(
        padding: const EdgeInsets.all(HgSpace.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayName,
                    style: HgText.bodyStrong.copyWith(color: c.text),
                  ),
                ),
                if (isSaving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                Switch(
                  value: !closed,
                  activeThumbColor: c.violet,
                  onChanged: (v) => _save(weekday, closed: !v),
                ),
              ],
            ),
            if (!closed) ...[
              const SizedBox(height: HgSpace.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeButton(
                    time: openTime,
                    color: c,
                    onTap: () => _pickTime(weekday, true),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: HgSpace.md),
                    child: Text(
                      '—',
                      style: HgText.body.copyWith(color: c.text),
                    ),
                  ),
                  _buildTimeButton(
                    time: closeTime,
                    color: c,
                    onTap: () => _pickTime(weekday, false),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: HgSpace.sm),
              Text(
                'Kapalı',
                style: HgText.caption.copyWith(color: c.textFaint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required String time,
    required HgColors color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HgSpace.md,
          vertical: HgSpace.sm,
        ),
        decoration: BoxDecoration(
          color: color.surfaceAlt,
          borderRadius: BorderRadius.circular(HgRadius.sm),
        ),
        child: Text(
          time,
          style: HgText.body.copyWith(color: color.violet),
        ),
      ),
    );
  }
}