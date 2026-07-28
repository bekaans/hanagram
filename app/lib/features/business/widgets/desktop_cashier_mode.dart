// Hanagram — masaüstü kasa modu
//
// Masaüstü genişliğinde 2 sütunlu POS (nokta satış) arayüzü.
import 'package:flutter/material.dart';

import 'package:hanagram_design/design.dart';

/// Masaüstü kasa modu — sadece geniş ekranlarda gösterilir.
class DesktopCashierMode extends StatelessWidget {
  const DesktopCashierMode({super.key, required this.c});

  final HgColors c;

  @override
  Widget build(BuildContext context) {
    if (!HgBreak.isDesktop(context)) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.point_of_sale, size: 18, color: c.violet),
            const SizedBox(width: HgSpace.sm),
            Text('Kasa Modu', style: HgText.heading.copyWith(color: c.text)),
          ],
        ),
        const SizedBox(height: HgSpace.md),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: HgSpace.sm,
              crossAxisSpacing: HgSpace.sm,
              childAspectRatio: 1.4,
              children: [
                _QuickAction(
                  icon: Icons.calendar_today,
                  label: 'Randevu',
                  color: c.violet,
                  c: c,
                ),
                _QuickAction(
                  icon: Icons.person,
                  label: 'Müşteri',
                  color: c.blue,
                  c: c,
                ),
                _QuickAction(
                  icon: Icons.shopping_bag,
                  label: 'Ürün',
                  color: c.coral,
                  c: c,
                ),
                _QuickAction(
                  icon: Icons.receipt_long,
                  label: 'Satış',
                  color: c.success,
                  c: c,
                ),
                _QuickAction(
                  icon: Icons.star,
                  label: 'Paket',
                  color: c.warning,
                  c: c,
                ),
                _QuickAction(
                  icon: Icons.group,
                  label: 'Referans',
                  color: c.violet,
                  c: c,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.c,
  });

  final IconData icon;
  final String label;
  final Color color;
  final HgColors c;

  @override
  Widget build(BuildContext context) {
    return HgCard(
      onTap: () {},
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(HgRadius.sm),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: HgSpace.sm),
          Text(label, style: HgText.small.copyWith(color: c.text)),
        ],
      ),
    );
  }
}
