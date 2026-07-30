// Hanagram Admin — sol kenar navigasyon rayı
//
// 5 sekme: Genel, Kullanıcılar, Görevler, Güncellemeler + Çıkış.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

class AdminRail extends StatelessWidget {
  const AdminRail({
    super.key,
    required this.tab,
    required this.onSelect,
    required this.onRefresh,
    required this.onLogout,
  });

  final int tab;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  static const _items = [
    (Icons.dashboard_outlined, 'Genel'),
    (Icons.people_outline, 'Kullanıcılar'),
    (Icons.system_update_outlined, 'Güncellemeler'),
    (Icons.vpn_key_outlined, 'Referanslar'),
    (Icons.verified_outlined, 'Doğrulamalar'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    return Container(
      width: 210,
      color: c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(HgSpace.lg),
            child: Row(
              children: [
                const BrandMark(size: 28),
                const SizedBox(width: HgSpace.sm),
                Text('Yönetim', style: HgText.heading.copyWith(color: c.text)),
              ],
            ),
          ),
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: HgSpace.sm, vertical: 2),
              child: Material(
                color: tab == i
                    ? c.violet.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(HgRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(HgRadius.md),
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.all(HgSpace.md),
                    child: Row(
                      children: [
                        Icon(_items[i].$1,
                            size: 18,
                            color: tab == i ? c.violet : c.textMuted),
                        const SizedBox(width: HgSpace.md),
                        Text(_items[i].$2,
                            style: HgText.body.copyWith(
                                color: tab == i ? c.violet : c.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(HgSpace.md),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: onRefresh,
                  icon: Icon(Icons.refresh, size: 16, color: c.textMuted),
                  label: Text('Yenile',
                      style: HgText.small.copyWith(color: c.textMuted)),
                ),
                TextButton.icon(
                  onPressed: onLogout,
                  icon: Icon(Icons.logout, size: 16, color: c.danger),
                  label: Text('Çıkış',
                      style: HgText.small.copyWith(color: c.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
