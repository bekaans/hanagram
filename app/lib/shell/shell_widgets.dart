// Hanagram — gezinme yardımcı widget'ları

import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import 'app_shell.dart';

// ─── Masaüstü yan ray ───

class SideRail extends StatelessWidget {
  const SideRail({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.onCompose,
    required this.extended,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompose;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final app = AppScope.of(context);
    final width = extended ? 232.0 : 76.0;

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Glass arka plan rengi temaya göre
    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : c.surface.withValues(alpha: 0.92);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : c.border.withValues(alpha: 0.4);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: glassBg,
            border: Border(
              right: BorderSide(color: glassBorder, width: 0.4),
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      HgSpace.lg, HgSpace.xl, HgSpace.lg, HgSpace.xl),
                  child: Row(
                    children: [
                      const BrandMark(size: 32),
                      if (extended) ...[
                        const SizedBox(width: HgSpace.md),
                        const Flexible(child: BrandWordmark(fontSize: 19)),
                      ],
                    ],
                  ),
                ),
                for (var i = 0; i < items.length; i++)
                  RailItem(
                    item: items[i],
                    active: i == index,
                    extended: extended,
                    onTap: () => onSelect(i),
                  ),
                const SizedBox(height: HgSpace.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HgSpace.md),
                  child: BrandButton(
                    label: extended ? 'Paylaş' : '+',
                    onPressed: onCompose,
                    expand: true,
                  ),
                ),
                const Spacer(),
                if (app.session != null)
                  Padding(
                    padding: const EdgeInsets.all(HgSpace.md),
                    child: Row(
                      children: [
                        Avatar(name: app.session!.name, size: 32),
                        if (extended) ...[
                          const SizedBox(width: HgSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.session!.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: HgText.caption.copyWith(color: c.text)),
                                Text('#${app.session!.memberNumber}',
                                    style: HgText.caption
                                        .copyWith(color: c.textFaint, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ray öğesi ───

class RailItem extends StatelessWidget {
  const RailItem({
    super.key,
    required this.item,
    required this.active,
    required this.extended,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final activeColor = isDark ? Colors.white : c.violet;
    final inactiveColor = isDark ? c.textMuted : c.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HgSpace.md, vertical: 3),
      child: Material(
        color: active
            ? (isDark
                ? c.violet.withValues(alpha: 0.14)
                : c.violet.withValues(alpha: 0.08))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(HgRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(HgRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: HgSpace.md, vertical: HgSpace.md),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  active ? item.activeIcon : item.icon,
                  size: 21,
                  color: active ? activeColor : inactiveColor,
                ),
                if (extended) ...[
                  const SizedBox(width: HgSpace.md),
                  Text(
                    item.label,
                    style: HgText.bodyStrong.copyWith(
                      color: active ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
