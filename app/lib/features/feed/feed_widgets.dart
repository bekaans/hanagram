// Hanagram — akış yardımcı widget'ları

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/utils.dart';
import 'package:hanagram_design/design.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_provider.dart';

// ─── Gönderi kartı ───

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.item});
  final FeedItem item;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked = widget.item.likedByMe;
  bool _saved = false;
  DateTime? _appeared;

  @override
  void initState() {
    super.initState();
    _appeared = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).signal(widget.item.id, 'view');
    });
  }

  @override
  void dispose() {
    final start = _appeared;
    if (start != null) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (ms >= 2000) {
        _stateRef?.signal(widget.item.id, 'dwell', dwellMs: ms);
      }
    }
    super.dispose();
  }

  AppState? _stateRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stateRef = AppScope.of(context);
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          userId: widget.item.authorHandle,
          isOwnProfile: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final it = widget.item;
    final app = AppScope.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    // Kart arka planı temaya göre
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : c.surface.withValues(alpha: 0.80);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : c.border.withValues(alpha: 0.3);

    return ClipRRect(
      borderRadius: BorderRadius.circular(HgRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(HgRadius.lg),
            border: Border.all(color: cardBorder, width: 0.3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    HgSpace.lg, HgSpace.lg, HgSpace.lg, HgSpace.md),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: Avatar(name: it.authorName, size: 40),
                    ),
                    const SizedBox(width: HgSpace.md),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openProfile(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.authorName,
                                style: HgText.bodyStrong.copyWith(color: c.text)),
                            Text('@${it.authorHandle} · ${relativeTime(DateTime.now().millisecondsSinceEpoch, it.createdAt)}',
                                style: HgText.caption.copyWith(color: c.textMuted)),
                          ],
                        ),
                      ),
                    ),
                    if (it.sponsored)
                      HgChip(label: 'Sponsorlu', color: c.warning, icon: CupertinoIcons.speaker_2)
                    else if (it.isExploration)
                      HgChip(label: 'Keşif', color: c.blue, icon: CupertinoIcons.compass),
                  ],
                ),
              ),
              if (it.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: HgSpace.lg),
                  child: Text(it.caption, style: HgText.body.copyWith(color: c.text)),
                ),
              if (it.topics.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      HgSpace.lg, HgSpace.md, HgSpace.lg, 0),
                  child: Wrap(
                    spacing: HgSpace.sm,
                    runSpacing: HgSpace.xs,
                    children: [
                      for (final t in it.topics)
                        _GlassHashtag(
                          label: '#$t',
                          isOwner: it.authorHandle == app.session?.handle,
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(HgSpace.lg),
                child: Row(
                  children: [
                    _Action(
                      icon: _liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      label: fmtCount(
                          it.likes - (it.likedByMe ? 1 : 0) + (_liked ? 1 : 0)),
                      color: _liked ? c.coral : c.textMuted,
                      onTap: () {
                        SettingsScope.of(context).hapticTap();
                        setState(() => _liked = !_liked);
                        app.signal(it.id, 'like');
                      },
                    ),
                    const SizedBox(width: HgSpace.xl),
                    _Action(
                      icon: CupertinoIcons.chat_bubble,
                      label: '${it.commentCount}',
                      color: c.textMuted,
                      onTap: () => app.signal(it.id, 'comment'),
                    ),
                    const SizedBox(width: HgSpace.xl),
                    _Action(
                      icon: CupertinoIcons.paperplane,
                      label: '',
                      color: c.textMuted,
                      onTap: () => app.signal(it.id, 'share'),
                    ),
                    const Spacer(),
                    _Action(
                      icon: _saved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                      label: '',
                      color: _saved ? c.violet : c.textMuted,
                      onTap: () {
                        setState(() => _saved = !_saved);
                        if (_saved) app.signal(it.id, 'save');
                      },
                    ),
                    const SizedBox(width: HgSpace.md),
                    _Action(
                      icon: CupertinoIcons.eye_slash,
                      label: '',
                      color: c.textFaint,
                      onTap: () {
                        app.signal(it.id, 'hide');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Bu tür içerik daha az gösterilecek'),
                            backgroundColor: c.surfaceAlt,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glass hashtag ───

class _GlassHashtag extends StatelessWidget {
  const _GlassHashtag({required this.label, required this.isOwner});

  final String label;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final c = HgTheme.of(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final tagBg = isDark
        ? Colors.white.withValues(alpha: isOwner ? 0.10 : 0.06)
        : c.violet.withValues(alpha: isOwner ? 0.12 : 0.06);
    final tagBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : c.violet.withValues(alpha: 0.15);
    final tagColor = isDark
        ? Colors.white.withValues(alpha: isOwner ? 0.8 : 0.35)
        : (isOwner ? c.violet : c.textMuted);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: isOwner ? 0 : 6, sigmaY: isOwner ? 0 : 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tagBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tagBorder, width: 0.3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: tagColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Eylem butonu ───

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HgRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: HgText.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              )),
            ],
          ],
        ),
      ),
    );
  }
}
