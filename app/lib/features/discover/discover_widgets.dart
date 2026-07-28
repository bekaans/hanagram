// Hanagram — keşfet yardımcı widget'ları

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import 'package:hanagram_design/design.dart';
import '../profile/profile_screen.dart';

// ─── Tam ekran içerik sayfası ───

class FullPageTile extends StatelessWidget {
  const FullPageTile({
    super.key,
    required this.item,
    required this.colors,
    required this.index,
    required this.total,
  });

  final FeedItem item;
  final List<Color> colors;
  final int index;
  final int total;

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          userId: item.authorHandle,
          isOwnProfile: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 90,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: Avatar(name: item.authorName, size: 36),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: Text(
                        item.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Takip Et',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.caption,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.topics.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in item.topics)
                        Text(
                          '#$t',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sağ taraftaki eylem butonu ───

class SideAction extends StatelessWidget {
  const SideAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Trending konu chip'i ───

class TrendingChip extends StatelessWidget {
  const TrendingChip({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.4,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
