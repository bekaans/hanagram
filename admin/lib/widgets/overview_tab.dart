// Hanagram Admin — genel bakış sekmesi
//
// Supabase'den canlı veri: kullanıcı sayıları, görevler, randevular,
// CRM kayıtları, referans kodları.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.overview});

  final Map<String, dynamic> overview;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);

    final totalUsers = overview['users'] ?? 0;
    final joined24h = overview['joined24h'] ?? 0;
    final joined7d = overview['joined7d'] ?? 0;
    final joined30d = overview['joined30d'] ?? 0;
    final business = overview['business'] ?? 0;
    final creator = overview['creator'] ?? 0;
    final personal = overview['personal'] ?? 0;
    final tasks = overview['tasks'] ?? 0;
    final appointments = overview['appointments'] ?? 0;
    final crm = overview['crm'] ?? 0;
    final invitesOpen = overview['invitesOpen'] ?? 0;
    final invitesUsed = overview['invitesUsed'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(HgSpace.xl),
      children: [
        Row(
          children: [
            Text('Genel bakış',
                style: HgText.display.copyWith(color: c.text)),
            const SizedBox(width: HgSpace.md),
            HgChip(label: 'CANLI', color: c.success),
          ],
        ),
        const SizedBox(height: HgSpace.xl),

        // ─── Kullanıcı İstatistikleri ───
        Text('Kullanıcılar', style: HgText.heading.copyWith(color: c.text)),
        const SizedBox(height: HgSpace.md),
        Wrap(
          spacing: HgSpace.md,
          runSpacing: HgSpace.md,
          children: [
            _stat(c, 'Toplam', '$totalUsers', Icons.people, c.violet),
            _stat(c, 'Son 24 saat', '$joined24h',
                Icons.person_add_outlined, c.success),
            _stat(c, 'Son 7 gün', '$joined7d', Icons.date_range, c.blue),
            _stat(c, 'Son 30 gün', '$joined30d', Icons.calendar_month, c.blue),
            _stat(c, 'İşletme', '$business',
                Icons.storefront_outlined, c.blue),
            _stat(c, 'Üretici', '$creator', Icons.auto_awesome, c.coral),
            _stat(c, 'Kişisel', '$personal', Icons.person_outline, c.violet),
          ],
        ),
        const SizedBox(height: HgSpace.xl),

        // ─── Aktivite ───
        Text('Aktivite', style: HgText.heading.copyWith(color: c.text)),
        const SizedBox(height: HgSpace.md),
        Wrap(
          spacing: HgSpace.md,
          runSpacing: HgSpace.md,
          children: [
            _stat(c, 'Görevler', '$tasks', Icons.task_alt, c.violet),
            _stat(c, 'Randevular', '$appointments',
                Icons.event_outlined, c.blue),
            _stat(c, 'CRM kayıtları', '$crm',
                Icons.receipt_long_outlined, c.coral),
          ],
        ),
        const SizedBox(height: HgSpace.xl),

        // ─── Referans Kodları ───
        Text('Referans kodları',
            style: HgText.heading.copyWith(color: c.text)),
        const SizedBox(height: HgSpace.md),
        Wrap(
          spacing: HgSpace.md,
          runSpacing: HgSpace.md,
          children: [
            _stat(c, 'Kullanılabilir', '$invitesOpen',
                Icons.confirmation_number_outlined, c.success),
            _stat(c, 'Kullanılan', '$invitesUsed',
                Icons.how_to_reg_outlined, c.warning),
          ],
        ),
        const SizedBox(height: HgSpace.xl),

        // ─── Hızlı Özet Tablosu ───
        HgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Özet', style: HgText.heading.copyWith(color: c.text)),
              const SizedBox(height: HgSpace.md),
              _kv(c, 'Kayıtlı kullanıcı', '$totalUsers'),
              _kv(c, 'Aktif görev', '$tasks'),
              _kv(c, 'Randevu', '$appointments'),
              _kv(c, 'CRM girişi', '$crm'),
              _kv(c, 'Toplam kod',
                  '${invitesOpen + invitesUsed} ($invitesOpen)'),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _stat(HgColors c, String label, String value,
      IconData icon, Color color) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(HgSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(HgRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: HgSpace.md),
          Text(value,
              style:
                  HgText.display.copyWith(color: c.text, fontSize: 28)),
          Text(label, style: HgText.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }

  static Widget _kv(HgColors c, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Text(k, style: HgText.small.copyWith(color: c.textMuted)),
          const Spacer(),
          Text(v, style: HgText.bodyStrong.copyWith(color: c.text)),
        ],
      ),
    );
  }
}
